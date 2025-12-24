defmodule EvalEx.ScorerTest do
  use ExUnit.Case, async: true

  alias EvalEx.{Sample, Scorer}

  # Test scorer implementation
  defmodule TestScorer do
    use Scorer

    @impl true
    def score(sample, _opts) do
      if sample.model_output == sample.target do
        {:ok, %{value: 1.0, answer: sample.model_output, explanation: "Match", metadata: %{}}}
      else
        {:ok, %{value: 0.0, answer: sample.model_output, explanation: "No match", metadata: %{}}}
      end
    end
  end

  defmodule CustomIdScorer do
    use Scorer

    @impl true
    def score(_sample, _opts) do
      {:ok, %{value: 1.0, answer: nil, explanation: nil, metadata: %{}}}
    end

    @impl true
    def scorer_id, do: "custom_scorer"
  end

  describe "behaviour" do
    test "implements score/2 callback" do
      sample = Sample.new(input: "test", target: "result") |> Sample.with_output("result")
      {:ok, score} = TestScorer.score(sample, [])

      assert score.value == 1.0
      assert score.answer == "result"
      assert score.explanation == "Match"
      assert score.metadata == %{}
    end

    test "returns error tuple on failure" do
      defmodule ErrorScorer do
        use Scorer

        @impl true
        def score(_sample, _opts) do
          {:error, :scoring_failed}
        end
      end

      sample = Sample.new(input: "test")
      assert {:error, :scoring_failed} = ErrorScorer.score(sample, [])
    end
  end

  describe "scorer_id/0" do
    test "generates default ID from module name" do
      assert TestScorer.scorer_id() == "test_scorer"
    end

    test "can be overridden" do
      assert CustomIdScorer.scorer_id() == "custom_scorer"
    end
  end

  describe "score struct" do
    test "contains all required fields" do
      sample = Sample.new(input: "test", target: "result") |> Sample.with_output("result")
      {:ok, score} = TestScorer.score(sample, [])

      assert Map.has_key?(score, :value)
      assert Map.has_key?(score, :answer)
      assert Map.has_key?(score, :explanation)
      assert Map.has_key?(score, :metadata)
    end
  end
end
