defmodule EvalEx do
  @moduledoc """
  Model evaluation harness for standardized benchmarking.

  EvalEx provides a framework for defining, running, and comparing model evaluations
  with built-in metrics, benchmark suites, and Crucible integration.

  ## Examples

      defmodule MyEval do
        use EvalEx.Evaluation

        @impl true
        def name, do: "proposer_scifact"

        @impl true
        def dataset, do: :scifact

        @impl true
        def metrics, do: [:entailment, :citation_accuracy, :schema_compliance]

        @impl true
        def evaluate(prediction, ground_truth) do
          %{
            entailment: EvalEx.Metrics.entailment(prediction, ground_truth),
            citation_accuracy: EvalEx.Metrics.citation_accuracy(prediction, ground_truth)
          }
        end
      end

      # Run evaluation
      {:ok, results} = EvalEx.run(MyEval, model_outputs)

  """

  alias EvalEx.{Runner, Result, Comparison}

  @doc """
  Runs an evaluation module with the given model outputs.

  ## Parameters

    * `evaluation` - Module implementing EvalEx.Evaluation behaviour
    * `model_outputs` - List of model predictions to evaluate
    * `opts` - Optional keyword list of options

  ## Options

    * `:ground_truth` - List of ground truth values (optional if dataset provides them)
    * `:parallel` - Run evaluations in parallel (default: true)
    * `:timeout` - Timeout per evaluation in ms (default: 5000)

  ## Returns

    * `{:ok, %EvalEx.Result{}}` - On successful evaluation
    * `{:error, reason}` - On failure

  """
  @spec run(module(), list(), keyword()) :: {:ok, Result.t()} | {:error, term()}
  def run(evaluation, model_outputs, opts \\ []) do
    Runner.run(evaluation, model_outputs, opts)
  end

  @doc """
  Compares multiple evaluation results.

  ## Parameters

    * `results` - List of EvalEx.Result structs to compare

  ## Returns

    * `%EvalEx.Comparison{}` - Comparison analysis

  """
  @spec compare(list(Result.t())) :: Comparison.t()
  def compare(results) do
    Comparison.compare(results)
  end

  @doc """
  Runs an evaluation with Crucible integration.

  ## Parameters

    * `evaluation` - Module implementing EvalEx.Evaluation behaviour
    * `model_outputs` - List of model predictions to evaluate
    * `opts` - Keyword list of options

  ## Options

    * `:experiment_name` - Name for the Crucible experiment (required)
    * `:track_metrics` - Whether to track metrics in Crucible (default: true)
    * All options from `run/3`

  """
  @spec run_with_crucible(module(), list(), keyword()) ::
          {:ok, Result.t()} | {:error, term()}
  def run_with_crucible(evaluation, model_outputs, opts \\ []) do
    with {:ok, result} <- run(evaluation, model_outputs, opts) do
      EvalEx.Crucible.submit(result, opts)
      {:ok, result}
    end
  end
end
