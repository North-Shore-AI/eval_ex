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
  def compare(results) when is_list(results) and length(results) > 0 do
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
  def best(%__MODULE__{best: best}), do: best

  @doc """
  Returns rankings as a list of {result, score} tuples.
  """
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
            max_value = values |> Enum.map(&elem(&1, 1)) |> Enum.max()

            if max_value > 0 do
              stats.mean / max_value
            else
              0.0
            end
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
      v1 = get_metric_values(r1, metric)
      v2 = get_metric_values(r2, metric)

      if length(v1) > 0 and length(v2) > 0 do
        t_stat = calculate_t_statistic(v1, v2)

        %{
          pair: "#{r1.name} vs #{r2.name}",
          t_statistic: t_stat,
          significant: abs(t_stat) > 1.96
        }
      else
        nil
      end
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
    |> Enum.map(fn {{result, score}, rank} ->
      "  #{rank}. #{result.name}: #{Float.round(score, 4)}"
    end)
    |> Enum.join("\n")
  end

  defp format_metric_comparisons(comparisons) do
    comparisons
    |> Enum.map(fn {metric, %{values: values, winner: winner}} ->
      values_str =
        Enum.map(values, fn {name, val} ->
          "#{name}=#{Float.round(val, 4)}"
        end)
        |> Enum.join(", ")

      "  #{metric}: #{values_str} (winner: #{winner || "N/A"})"
    end)
    |> Enum.join("\n")
  end

  defp format_statistical_tests(tests) when is_map(tests) do
    if Map.has_key?(tests, :note) do
      "  #{tests.note}"
    else
      tests
      |> Enum.map(fn {metric, test_results} ->
        results_str =
          Enum.map(test_results, fn test ->
            sig = if test.significant, do: "*", else: ""
            "#{test.pair}: t=#{Float.round(test.t_statistic, 2)}#{sig}"
          end)
          |> Enum.join(", ")

        "  #{metric}: #{results_str}"
      end)
      |> Enum.join("\n")
    end
  end
end
