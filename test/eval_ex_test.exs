defmodule EvalExTest do
  use ExUnit.Case
  doctest EvalEx

  alias EvalEx.{Result, Comparison}

  # Test evaluation module
  defmodule TestEval do
    use EvalEx.Evaluation

    @impl true
    def name, do: "test_eval"

    @impl true
    def dataset, do: :test_dataset

    @impl true
    def metrics, do: [:accuracy, :f1]

    @impl true
    def evaluate(prediction, ground_truth) do
      %{
        accuracy: if(prediction == ground_truth, do: 1.0, else: 0.0),
        f1: EvalEx.Metrics.f1(to_string(prediction), to_string(ground_truth))
      }
    end
  end

  describe "EvalEx.run/3" do
    test "runs evaluation with provided ground truth" do
      predictions = ["cat", "dog", "bird"]
      ground_truth = ["cat", "dog", "fish"]

      {:ok, result} = EvalEx.run(TestEval, predictions, ground_truth: ground_truth)

      assert result.name == "test_eval"
      assert result.dataset == :test_dataset
      assert result.samples == 3
      assert result.aggregated_metrics.accuracy.mean > 0.0
    end

    test "returns error when predictions and ground truth lengths mismatch" do
      predictions = ["cat", "dog"]
      ground_truth = ["cat"]

      assert {:error, :length_mismatch} =
               EvalEx.run(TestEval, predictions, ground_truth: ground_truth)
    end
  end

  describe "EvalEx.compare/1" do
    test "compares multiple results" do
      result1 = Result.new("eval1", :dataset, [%{acc: 0.8}], 10, 100)
      result2 = Result.new("eval2", :dataset, [%{acc: 0.9}], 10, 100)

      comparison = EvalEx.compare([result1, result2])

      assert %Comparison{} = comparison
      assert comparison.best.name == "eval2"
      assert length(comparison.rankings) == 2
    end
  end
end
