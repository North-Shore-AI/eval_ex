defmodule EvalEx.Scorer.ExactMatchTest do
  use ExUnit.Case, async: true

  alias EvalEx.{Sample, Scorer.ExactMatch}

  describe "score/2" do
    test "returns 1.0 for exact match" do
      sample = Sample.new(input: "test", target: "answer") |> Sample.with_output("answer")
      {:ok, score} = ExactMatch.score(sample, [])

      assert score.value == 1.0
      assert score.answer == "answer"
      assert score.explanation == nil
      assert score.metadata == %{}
    end

    test "returns 0.0 for no match" do
      sample = Sample.new(input: "test", target: "answer") |> Sample.with_output("wrong")
      {:ok, score} = ExactMatch.score(sample, [])

      assert score.value == 0.0
      assert score.answer == "wrong"
    end

    test "normalizes case" do
      sample = Sample.new(input: "test", target: "ANSWER") |> Sample.with_output("answer")
      {:ok, score} = ExactMatch.score(sample, [])

      assert score.value == 1.0
    end

    test "normalizes whitespace" do
      sample = Sample.new(input: "test", target: "  answer  ") |> Sample.with_output("answer")
      {:ok, score} = ExactMatch.score(sample, [])

      assert score.value == 1.0
    end

    test "handles both case and whitespace normalization" do
      sample = Sample.new(input: "test", target: "  ANSWER  ") |> Sample.with_output("  answer  ")
      {:ok, score} = ExactMatch.score(sample, [])

      assert score.value == 1.0
    end

    test "matches against multiple targets" do
      sample =
        Sample.new(input: "test", target: ["Paris", "paris", "PARIS"])
        |> Sample.with_output("Paris")

      {:ok, score} = ExactMatch.score(sample, [])

      assert score.value == 1.0
    end

    test "matches any target in list" do
      sample =
        Sample.new(input: "test", target: ["option1", "option2", "option3"])
        |> Sample.with_output("option2")

      {:ok, score} = ExactMatch.score(sample, [])

      assert score.value == 1.0
    end

    test "returns 0.0 when no target in list matches" do
      sample =
        Sample.new(input: "test", target: ["option1", "option2"])
        |> Sample.with_output("option3")

      {:ok, score} = ExactMatch.score(sample, [])

      assert score.value == 0.0
    end

    test "handles nil model_output" do
      sample = Sample.new(input: "test", target: "answer")
      {:ok, score} = ExactMatch.score(sample, [])

      assert score.value == 0.0
      assert score.answer == ""
    end

    test "handles empty string target" do
      sample = Sample.new(input: "test", target: "") |> Sample.with_output("")
      {:ok, score} = ExactMatch.score(sample, [])

      assert score.value == 1.0
    end
  end

  describe "scorer_id/0" do
    test "returns default ID" do
      assert ExactMatch.scorer_id() == "exact_match"
    end
  end
end
