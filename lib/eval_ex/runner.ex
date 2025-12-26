defmodule EvalEx.Runner do
  @moduledoc """
  Executes evaluations and manages the evaluation lifecycle.
  """

  alias EvalEx.Result

  @default_opts [
    parallel: true,
    timeout: 5000,
    ground_truth: nil
  ]

  @doc """
  Runs an evaluation module with the given model outputs.
  """
  @spec run(module(), list(), keyword()) :: {:ok, Result.t()} | {:error, term()}
  def run(evaluation, model_outputs, opts \\ []) do
    opts = Keyword.merge(@default_opts, opts)
    start_time = System.monotonic_time(:millisecond)

    with {:ok, ground_truth} <- get_ground_truth(evaluation, opts),
         {:ok, paired_data} <- pair_data(model_outputs, ground_truth),
         {:ok, metrics} <- evaluate_all(evaluation, paired_data, opts) do
      duration = System.monotonic_time(:millisecond) - start_time

      result =
        Result.new(
          evaluation.name(),
          evaluation.dataset(),
          metrics,
          length(paired_data),
          duration,
          metadata: build_metadata(evaluation, opts)
        )

      {:ok, result}
    end
  end

  defp get_ground_truth(evaluation, opts) do
    case Keyword.get(opts, :ground_truth) do
      nil ->
        # Build module name dynamically to avoid compile-time warning on optional module
        datasets_module = Module.concat([EvalEx, Datasets])

        if Code.ensure_loaded?(datasets_module) do
          datasets_module.load(evaluation.dataset())
        else
          {:error, :no_ground_truth}
        end

      truth when is_list(truth) ->
        {:ok, truth}

      _ ->
        {:error, :invalid_ground_truth}
    end
  end

  defp pair_data(predictions, ground_truth) do
    if length(predictions) == length(ground_truth) do
      {:ok, Enum.zip(predictions, ground_truth)}
    else
      {:error, :length_mismatch}
    end
  end

  defp evaluate_all(evaluation, paired_data, opts) do
    if Keyword.get(opts, :parallel) do
      evaluate_parallel(evaluation, paired_data, opts)
    else
      evaluate_sequential(evaluation, paired_data, opts)
    end
  end

  defp evaluate_sequential(evaluation, paired_data, _opts) do
    metrics =
      Enum.map(paired_data, fn {prediction, truth} ->
        preprocessed = evaluation.preprocess(prediction)
        result = evaluation.evaluate(preprocessed, truth)
        evaluation.postprocess(result)
      end)

    {:ok, metrics}
  end

  defp evaluate_parallel(evaluation, paired_data, opts) do
    timeout = Keyword.get(opts, :timeout)

    tasks =
      Enum.map(paired_data, fn {prediction, truth} ->
        Task.async(fn ->
          preprocessed = evaluation.preprocess(prediction)
          result = evaluation.evaluate(preprocessed, truth)
          evaluation.postprocess(result)
        end)
      end)

    try do
      metrics = Task.await_many(tasks, timeout)
      {:ok, metrics}
    catch
      :exit, {:timeout, _} -> {:error, :evaluation_timeout}
    end
  end

  defp build_metadata(evaluation, opts) do
    %{
      metrics: evaluation.metrics(),
      parallel: Keyword.get(opts, :parallel),
      timeout: Keyword.get(opts, :timeout)
    }
  end
end
