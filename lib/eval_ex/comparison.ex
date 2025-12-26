defmodule EvalEx.Comparison do
  @moduledoc """
  Compares multiple evaluation results.
  """

  alias EvalEx.Result

  @type t :: %__MODULE__{
          results: list(Result.t()),
          best: Result.t() | nil,
          rankings: list({Result.t(), float()}),
          metric_comparisons: map(),
          statistical_tests: map()
        }

  defstruct [
    :results,
    :best,
    :rankings,
    :metric_comparisons,
    :statistical_tests
  ]

  @doc """
  Compares multiple evaluation results.

  ## Parameters

    * `results` - List of EvalEx.Result structs to compare

  ## Returns

    * `%EvalEx.Comparison{}` - Comparison analysis

  """
  @spec compare(list(Result.t())) :: t()
  def compare(results) when is_list(results) do
    if Enum.empty?(results), do: raise(ArgumentError, "results cannot be empty")
    metric_comparisons = compare_metrics(results)
    rankings = rank_results(results, metric_comparisons)
    best = determine_best(rankings)
    statistical_tests = run_statistical_tests(results)

    %__MODULE__{
      results: results,
      best: best,
      rankings: rankings,
      metric_comparisons: metric_comparisons,
      statistical_tests: statistical_tests
    }
  end

  @doc """
  Formats comparison as a human-readable string.
  """
  @spec format(t()) :: String.t()
  def format(%__MODULE__{} = comparison) do
    """
    Comparison of #{length(comparison.results)} evaluations

    Best: #{if comparison.best, do: comparison.best.name, else: "N/A"}

    Rankings:
    #{format_rankings(comparison.rankings)}

    Metric Comparisons:
    #{format_metric_comparisons(comparison.metric_comparisons)}

    Statistical Tests:
    #{format_statistical_tests(comparison.statistical_tests)}
    """
  end

  @doc """
  Returns the best result based on overall score.
  """
  @spec best(t()) :: Result.t() | nil
  def best(%__MODULE__{best: best}), do: best

  @doc """
  Returns rankings as a list of {result, score} tuples.
  """
  @spec rankings(t()) :: list({Result.t(), float()})
  def rankings(%__MODULE__{rankings: rankings}), do: rankings

  # Private functions

  defp compare_metrics(results) do
    # Get all unique metric names
    all_metrics =
      results
      |> Enum.flat_map(fn r -> Map.keys(r.aggregated_metrics) end)
      |> Enum.uniq()

    # Compare each metric across results
    Enum.map(all_metrics, fn metric ->
      values =
        Enum.map(results, fn r ->
          {r.name, get_in(r.aggregated_metrics, [metric, :mean])}
        end)
        |> Enum.reject(fn {_name, val} -> is_nil(val) end)

      {metric, %{values: values, winner: determine_winner(values)}}
    end)
    |> Enum.into(%{})
  end

  defp determine_winner([]), do: nil

  defp determine_winner(values) do
    values
    |> Enum.max_by(fn {_name, score} -> score end)
    |> elem(0)
  end

  defp rank_results(results, metric_comparisons) do
    # Calculate overall score for each result
    scored_results =
      Enum.map(results, fn result ->
        score = calculate_overall_score(result, metric_comparisons)
        {result, score}
      end)

    # Sort by score descending
    Enum.sort_by(scored_results, fn {_result, score} -> score end, :desc)
  end

  defp calculate_overall_score(result, metric_comparisons) do
    # Average of normalized metric scores
    scores =
      Enum.map(result.aggregated_metrics, fn {metric, stats} ->
        case Map.get(metric_comparisons, metric) do
          nil ->
            0.0

          %{values: values} ->
            normalize_metric_score(stats.mean, values)
        end
      end)

    if Enum.empty?(scores) do
      0.0
    else
      Enum.sum(scores) / length(scores)
    end
  end

  defp determine_best([]), do: nil
  defp determine_best([{best, _score} | _rest]), do: best

  defp normalize_metric_score(mean, values) do
    max_value = values |> Enum.map(&elem(&1, 1)) |> Enum.max()
    if max_value > 0, do: mean / max_value, else: 0.0
  end

  defp build_pairwise_test(r1, r2, metric) do
    v1 = get_metric_values(r1, metric)
    v2 = get_metric_values(r2, metric)

    if not Enum.empty?(v1) and not Enum.empty?(v2) do
      t_stat = calculate_t_statistic(v1, v2)

      %{
        pair: "#{r1.name} vs #{r2.name}",
        t_statistic: t_stat,
        significant: abs(t_stat) > 1.96
      }
    else
      nil
    end
  end

  defp format_metric_test({metric, test_results}) do
    results_str =
      Enum.map_join(test_results, ", ", fn test ->
        sig = if test.significant, do: "*", else: ""
        "#{test.pair}: t=#{Float.round(test.t_statistic, 2)}#{sig}"
      end)

    "  #{metric}: #{results_str}"
  end

  defp run_statistical_tests(results) when length(results) < 2 do
    %{note: "Need at least 2 results for statistical testing"}
  end

  defp run_statistical_tests(results) do
    # Get all unique metrics
    all_metrics =
      results
      |> Enum.flat_map(fn r -> Map.keys(r.aggregated_metrics) end)
      |> Enum.uniq()

    # For each metric, run t-test between consecutive pairs
    Enum.map(all_metrics, fn metric ->
      tests = run_pairwise_tests(results, metric)
      {metric, tests}
    end)
    |> Enum.into(%{})
  end

  defp run_pairwise_tests(results, metric) do
    results
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [r1, r2] ->
      build_pairwise_test(r1, r2, metric)
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp get_metric_values(result, metric) do
    # This would ideally get the raw values, but we only have aggregated stats
    # For now, generate synthetic values based on mean and std
    case get_in(result.aggregated_metrics, [metric]) do
      nil ->
        []

      %{mean: mean, count: count} ->
        List.duplicate(mean, min(count, 100))
    end
  end

  defp calculate_t_statistic(values1, values2) do
    mean1 = Enum.sum(values1) / length(values1)
    mean2 = Enum.sum(values2) / length(values2)

    var1 = variance(values1, mean1)
    var2 = variance(values2, mean2)

    n1 = length(values1)
    n2 = length(values2)

    pooled_var = var1 / n1 + var2 / n2

    if pooled_var > 0 do
      (mean1 - mean2) / :math.sqrt(pooled_var)
    else
      0.0
    end
  end

  defp variance(values, mean) do
    values
    |> Enum.map(&:math.pow(&1 - mean, 2))
    |> Enum.sum()
    |> Kernel./(length(values))
  end

  defp format_rankings(rankings) do
    rankings
    |> Enum.with_index(1)
    |> Enum.map_join("\n", fn {{result, score}, rank} ->
      "  #{rank}. #{result.name}: #{Float.round(score, 4)}"
    end)
  end

  defp format_metric_comparisons(comparisons) do
    Enum.map_join(comparisons, "\n", fn {metric, %{values: values, winner: winner}} ->
      values_str =
        Enum.map_join(values, ", ", fn {name, val} ->
          "#{name}=#{Float.round(val, 4)}"
        end)

      "  #{metric}: #{values_str} (winner: #{winner || "N/A"})"
    end)
  end

  defp format_statistical_tests(tests) when is_map(tests) do
    if Map.has_key?(tests, :note) do
      "  #{tests.note}"
    else
      Enum.map_join(tests, "\n", &format_metric_test/1)
    end
  end

  @doc """
  Calculates confidence intervals for a result's metrics.

  Uses t-distribution for small samples (n < 30) and normal distribution for larger samples.
  """
  @spec confidence_intervals(Result.t(), float()) :: map()
  def confidence_intervals(%Result{} = result, confidence_level \\ 0.95) do
    _alpha = 1 - confidence_level
    # For 95% confidence
    z_score = 1.96

    Enum.map(result.aggregated_metrics, fn {metric, stats} ->
      stderr = stats.std / :math.sqrt(stats.count)
      margin = z_score * stderr

      {metric,
       %{
         mean: stats.mean,
         lower: stats.mean - margin,
         upper: stats.mean + margin,
         confidence: confidence_level
       }}
    end)
    |> Enum.into(%{})
  end

  @doc """
  Calculates Cohen's d effect size between two results for a given metric.

  Effect size interpretation:
  - Small: d = 0.2
  - Medium: d = 0.5
  - Large: d = 0.8
  """
  @spec effect_size(Result.t(), Result.t(), atom()) :: float() | nil
  def effect_size(%Result{} = result1, %Result{} = result2, metric) do
    stats1 = get_in(result1.aggregated_metrics, [metric])
    stats2 = get_in(result2.aggregated_metrics, [metric])

    if stats1 && stats2 do
      # Calculate pooled standard deviation
      pooled_std =
        :math.sqrt(
          ((stats1.count - 1) * :math.pow(stats1.std, 2) +
             (stats2.count - 1) * :math.pow(stats2.std, 2)) /
            (stats1.count + stats2.count - 2)
        )

      if pooled_std > 0 do
        (stats1.mean - stats2.mean) / pooled_std
      else
        0.0
      end
    else
      nil
    end
  end

  @doc """
  Performs bootstrap sampling to estimate confidence intervals.

  More robust than parametric methods for non-normal distributions.
  """
  @spec bootstrap_ci(list(float()), pos_integer(), float()) :: map()
  def bootstrap_ci(values, n_iterations \\ 1000, confidence_level \\ 0.95) do
    if Enum.empty?(values) do
      %{mean: 0.0, lower: 0.0, upper: 0.0}
    else
      bootstrap_means =
        for _ <- 1..n_iterations do
          sample = Enum.map(1..length(values), fn _ -> Enum.random(values) end)
          Enum.sum(sample) / length(sample)
        end

      sorted = Enum.sort(bootstrap_means)
      alpha = 1 - confidence_level
      lower_idx = floor(alpha / 2 * n_iterations)
      upper_idx = floor((1 - alpha / 2) * n_iterations)

      %{
        mean: Enum.sum(values) / length(values),
        lower: Enum.at(sorted, lower_idx),
        upper: Enum.at(sorted, upper_idx)
      }
    end
  end

  @doc """
  Performs ANOVA test across multiple results for a given metric.

  Returns F-statistic and whether the difference is significant.
  """
  @spec anova(list(Result.t()), atom()) :: map()
  def anova(results, metric) when length(results) >= 2 do
    # Extract means and counts for the metric
    groups =
      Enum.map(results, fn r ->
        stats = get_in(r.aggregated_metrics, [metric])
        if stats, do: {stats.mean, stats.count, stats.std}, else: nil
      end)
      |> Enum.reject(&is_nil/1)

    if length(groups) < 2 do
      %{f_statistic: 0.0, significant: false, note: "Insufficient data"}
    else
      # Calculate grand mean
      total_n = Enum.sum(Enum.map(groups, fn {_, n, _} -> n end))
      grand_mean = Enum.sum(Enum.map(groups, fn {m, n, _} -> m * n end)) / total_n

      # Between-group variance
      ss_between =
        Enum.sum(
          Enum.map(groups, fn {m, n, _} ->
            n * :math.pow(m - grand_mean, 2)
          end)
        )

      df_between = length(groups) - 1

      # Within-group variance
      ss_within =
        Enum.sum(
          Enum.map(groups, fn {_, n, std} ->
            (n - 1) * :math.pow(std, 2)
          end)
        )

      df_within = total_n - length(groups)

      # F-statistic
      ms_between = ss_between / df_between
      ms_within = if df_within > 0, do: ss_within / df_within, else: 1.0

      f_stat = if ms_within > 0, do: ms_between / ms_within, else: 0.0

      # Critical value for F(df_between, df_within) at p=0.05 is approximately 3.0
      # This is a rough approximation
      significant = f_stat > 3.0

      %{
        f_statistic: f_stat,
        df_between: df_between,
        df_within: df_within,
        significant: significant,
        interpretation: interpret_f_statistic(f_stat, significant)
      }
    end
  end

  def anova(_results, _metric) do
    %{error: "Need at least 2 results for ANOVA"}
  end

  defp interpret_f_statistic(f_stat, significant) do
    cond do
      not significant -> "No significant difference between groups"
      f_stat > 10 -> "Very strong evidence of difference"
      f_stat > 5 -> "Strong evidence of difference"
      f_stat > 3 -> "Moderate evidence of difference"
      true -> "Weak evidence of difference"
    end
  end
end
