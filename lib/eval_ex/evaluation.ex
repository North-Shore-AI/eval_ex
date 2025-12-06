defmodule EvalEx.Evaluation do
  @moduledoc """
  Behaviour for defining model evaluations.

  Implement this behaviour to create custom evaluations with standardized
  structure and execution.

  ## Example

      defmodule MyEvaluation do
        use EvalEx.Evaluation

        @impl true
        def name, do: "my_custom_eval"

        @impl true
        def dataset, do: :custom_dataset

        @impl true
        def metrics, do: [:accuracy, :f1]

        @impl true
        def evaluate(prediction, ground_truth) do
          %{
            accuracy: compute_accuracy(prediction, ground_truth),
            f1: compute_f1(prediction, ground_truth)
          }
        end

        defp compute_accuracy(pred, truth), do: if(pred == truth, do: 1.0, else: 0.0)
        defp compute_f1(pred, truth), do: EvalEx.Metrics.f1(pred, truth)
      end

  """

  @doc """
  Returns the name of the evaluation.
  """
  @callback name() :: String.t()

  @doc """
  Returns the dataset identifier.
  """
  @callback dataset() :: atom()

  @doc """
  Returns the list of metrics to compute.
  """
  @callback metrics() :: list(atom())

  @doc """
  Evaluates a single prediction against ground truth.

  Returns a map of metric names to values.
  """
  @callback evaluate(prediction :: term(), ground_truth :: term()) :: map()

  @doc """
  Optional: Preprocess predictions before evaluation.
  """
  @callback preprocess(prediction :: term()) :: term()

  @doc """
  Optional: Postprocess evaluation results.
  """
  @callback postprocess(results :: map()) :: map()

  @optional_callbacks preprocess: 1, postprocess: 1

  defmacro __using__(_opts) do
    quote do
      @behaviour EvalEx.Evaluation

      @impl true
      def preprocess(prediction), do: prediction

      @impl true
      def postprocess(results), do: results

      defoverridable preprocess: 1, postprocess: 1
    end
  end
end
