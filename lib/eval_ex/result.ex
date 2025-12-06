defmodule EvalEx.Result do
  @moduledoc """
  Represents the results of an evaluation run.
  """

  @type t :: %__MODULE__{
          name: String.t(),
          dataset: atom(),
          metrics: map(),
          aggregated_metrics: map(),
          samples: non_neg_integer(),
          duration_ms: non_neg_integer(),
          timestamp: DateTime.t(),
          metadata: map()
        }

  @enforce_keys [:name, :dataset, :metrics, :aggregated_metrics, :samples, :duration_ms]
  defstruct [
    :name,
    :dataset,
    :metrics,
    :aggregated_metrics,
    :samples,
    :duration_ms,
    timestamp: nil,
    metadata: %{}
  ]

  @doc """
  Creates a new Result struct.

  ## Parameters

    * `name` - Name of the evaluation
    * `dataset` - Dataset identifier
    * `metrics` - List of individual sample metrics
    * `samples` - Number of samples evaluated
    * `duration_ms` - Total duration in milliseconds
    * `opts` - Optional metadata

  """
  def new(name, dataset, metrics, samples, duration_ms, opts \\ []) do
    aggregated = aggregate_metrics(metrics)

    %__MODULE__{
      name: name,
      dataset: dataset,
      metrics: metrics,
      aggregated_metrics: aggregated,
      samples: samples,
      duration_ms: duration_ms,
      timestamp: DateTime.utc_now(),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Aggregates individual sample metrics into summary statistics.
  """
  def aggregate_metrics(metrics) when is_list(metrics) do
    metrics
    |> Enum.reduce(%{}, fn sample_metrics, acc ->
      Enum.reduce(sample_metrics, acc, fn {metric_name, value}, inner_acc ->
        Map.update(inner_acc, metric_name, [value], &[value | &1])
      end)
    end)
    |> Enum.map(fn {metric_name, values} ->
      {metric_name,
       %{
         mean: mean(values),
         std: std(values),
         min: Enum.min(values),
         max: Enum.max(values),
         median: median(values),
         count: length(values)
       }}
    end)
    |> Enum.into(%{})
  end

  @doc """
  Converts result to a summary map.
  """
  def to_summary(%__MODULE__{} = result) do
    %{
      name: result.name,
      dataset: result.dataset,
      samples: result.samples,
      duration_ms: result.duration_ms,
      metrics:
        Enum.map(result.aggregated_metrics, fn {name, stats} ->
          {name, stats.mean}
        end)
        |> Enum.into(%{}),
      timestamp: result.timestamp
    }
  end

  @doc """
  Formats result as a human-readable string.
  """
  def format(%__MODULE__{} = result) do
    """
    Evaluation: #{result.name}
    Dataset: #{result.dataset}
    Samples: #{result.samples}
    Duration: #{result.duration_ms}ms

    Metrics:
    #{format_metrics(result.aggregated_metrics)}
    """
  end

  defp format_metrics(metrics) do
    metrics
    |> Enum.map(fn {name, stats} ->
      "  #{name}: #{Float.round(stats.mean, 4)} (±#{Float.round(stats.std, 4)})"
    end)
    |> Enum.join("\n")
  end

  # Statistical helpers
  defp mean([]), do: 0.0
  defp mean(values), do: Enum.sum(values) / length(values)

  defp std([]), do: 0.0

  defp std(values) do
    m = mean(values)
    variance = Enum.map(values, &:math.pow(&1 - m, 2)) |> mean()
    :math.sqrt(variance)
  end

  defp median([]), do: 0.0

  defp median(values) do
    sorted = Enum.sort(values)
    len = length(sorted)
    mid = div(len, 2)

    if rem(len, 2) == 0 do
      (Enum.at(sorted, mid - 1) + Enum.at(sorted, mid)) / 2
    else
      Enum.at(sorted, mid)
    end
  end
end
