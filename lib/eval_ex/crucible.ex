defmodule EvalEx.Crucible do
  @moduledoc """
  Integration with Crucible Framework for experiment tracking.

  Submits evaluation results to Crucible for tracking, comparison,
  and visualization in the Crucible UI.
  """

  alias EvalEx.Result

  @doc """
  Submits evaluation results to Crucible.

  ## Parameters

    * `result` - EvalEx.Result struct
    * `opts` - Keyword list of options

  ## Options

    * `:experiment_name` - Name for the Crucible experiment (required)
    * `:track_metrics` - Whether to track metrics (default: true)
    * `:tags` - List of tags for the experiment
    * `:description` - Description of the experiment

  """
  @spec submit(Result.t(), keyword()) :: {:ok, atom()} | {:error, term()}
  def submit(%Result{} = result, opts \\ []) do
    experiment_name = Keyword.fetch!(opts, :experiment_name)
    track_metrics = Keyword.get(opts, :track_metrics, true)

    experiment_data = %{
      name: experiment_name,
      evaluation: result.name,
      dataset: result.dataset,
      samples: result.samples,
      duration_ms: result.duration_ms,
      timestamp: result.timestamp,
      tags: Keyword.get(opts, :tags, []),
      description: Keyword.get(opts, :description, ""),
      metrics: if(track_metrics, do: result.aggregated_metrics, else: %{}),
      metadata: result.metadata
    }

    # Check if Crucible is available
    case Code.ensure_loaded?(Crucible.Experiment) do
      true ->
        submit_to_crucible(experiment_data)

      false ->
        # Fallback: log to console
        log_experiment(experiment_data)
        {:ok, :logged}
    end
  end

  defp submit_to_crucible(experiment_data) do
    # NOTE: Placeholder - production would call Crucible.Experiment.create/1 or similar
    # For now, we just log
    log_experiment(experiment_data)
    {:ok, :submitted}
  end

  defp log_experiment(experiment_data) do
    require Logger

    Logger.info("""
    EvalEx Crucible Submission:
      Experiment: #{experiment_data.name}
      Evaluation: #{experiment_data.evaluation}
      Dataset: #{experiment_data.dataset}
      Samples: #{experiment_data.samples}
      Duration: #{experiment_data.duration_ms}ms
      Metrics: #{inspect(experiment_data.metrics)}
    """)
  end

  @doc """
  Formats result for Crucible telemetry events.
  """
  @spec to_telemetry_events(Result.t()) :: list(map())
  def to_telemetry_events(%Result{} = result) do
    result.aggregated_metrics
    |> Enum.map(fn {metric_name, stats} ->
      %{
        metric: metric_name,
        value: stats.mean,
        std: stats.std,
        min: stats.min,
        max: stats.max,
        count: stats.count,
        timestamp: result.timestamp
      }
    end)
  end

  @doc """
  Exports result in Crucible-compatible format.
  """
  @spec export(Result.t(), :json | :map) :: {:ok, String.t() | map()} | {:error, atom()}
  def export(%Result{} = result, format \\ :json) do
    data = %{
      evaluation: result.name,
      dataset: result.dataset,
      samples: result.samples,
      duration_ms: result.duration_ms,
      timestamp: DateTime.to_iso8601(result.timestamp),
      metrics: result.aggregated_metrics,
      metadata: result.metadata
    }

    case format do
      :json -> Jason.encode(data)
      :map -> {:ok, data}
      _ -> {:error, :unsupported_format}
    end
  end
end
