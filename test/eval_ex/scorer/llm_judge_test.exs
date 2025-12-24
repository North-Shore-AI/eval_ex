defmodule EvalEx.Scorer.LLMJudgeTest do
  use ExUnit.Case, async: true

  alias EvalEx.{Sample, Scorer.LLMJudge}

  describe "score/2" do
    test "requires generate_fn in opts" do
      sample = Sample.new(input: "test", target: "answer") |> Sample.with_output("answer")

      assert_raise KeyError, fn ->
        LLMJudge.score(sample, [])
      end
    end

    test "returns 1.0 when LLM judges as CORRECT" do
      generate_fn = fn _messages, _opts ->
        {:ok, %{content: "This is CORRECT because it matches the expected answer."}}
      end

      sample = Sample.new(input: "What is 2+2?", target: "4") |> Sample.with_output("4")
      {:ok, score} = LLMJudge.score(sample, generate_fn: generate_fn)

      assert score.value == 1.0
      assert score.answer == "4"
      assert score.explanation == "This is CORRECT because it matches the expected answer."
      assert score.metadata.grade == :correct
    end

    test "returns 0.0 when LLM judges as INCORRECT" do
      generate_fn = fn _messages, _opts ->
        {:ok, %{content: "This is INCORRECT. The answer should be 4, not 5."}}
      end

      sample = Sample.new(input: "What is 2+2?", target: "4") |> Sample.with_output("5")
      {:ok, score} = LLMJudge.score(sample, generate_fn: generate_fn)

      assert score.value == 0.0
      assert score.answer == "5"
      assert score.explanation == "This is INCORRECT. The answer should be 4, not 5."
      assert score.metadata.grade == :incorrect
    end

    test "defaults to INCORRECT when response is ambiguous" do
      generate_fn = fn _messages, _opts ->
        {:ok, %{content: "This is unclear and uncertain."}}
      end

      sample = Sample.new(input: "test", target: "answer") |> Sample.with_output("maybe")
      {:ok, score} = LLMJudge.score(sample, generate_fn: generate_fn)

      assert score.value == 0.0
      assert score.metadata.grade == :incorrect
    end

    test "builds prompt with input, target, and response" do
      {:ok, captured_messages} = Agent.start_link(fn -> nil end)

      generate_fn = fn messages, _opts ->
        Agent.update(captured_messages, fn _ -> messages end)
        {:ok, %{content: "CORRECT"}}
      end

      sample = Sample.new(input: "What is 2+2?", target: "4") |> Sample.with_output("4")
      {:ok, _score} = LLMJudge.score(sample, generate_fn: generate_fn)

      messages = Agent.get(captured_messages, & &1)
      assert [%{role: "user", content: prompt}] = messages
      assert prompt =~ "What is 2+2?"
      assert prompt =~ "4"
    end

    test "supports custom prompt template" do
      {:ok, captured_messages} = Agent.start_link(fn -> nil end)

      generate_fn = fn messages, _opts ->
        Agent.update(captured_messages, fn _ -> messages end)
        {:ok, %{content: "CORRECT"}}
      end

      custom_prompt = "Q: {input}\nA: {response}\nExpected: {target}\nGrade:"

      sample = Sample.new(input: "test", target: "answer") |> Sample.with_output("answer")
      {:ok, _score} = LLMJudge.score(sample, generate_fn: generate_fn, prompt: custom_prompt)

      messages = Agent.get(captured_messages, & &1)
      [%{content: prompt}] = messages
      assert prompt =~ "Q: test"
      assert prompt =~ "A: answer"
      assert prompt =~ "Expected: answer"
    end

    test "handles nil model_output" do
      generate_fn = fn _messages, _opts ->
        {:ok, %{content: "INCORRECT - no output provided"}}
      end

      sample = Sample.new(input: "test", target: "answer")
      {:ok, score} = LLMJudge.score(sample, generate_fn: generate_fn)

      assert score.value == 0.0
      assert score.answer == nil
    end

    test "propagates generate_fn errors" do
      generate_fn = fn _messages, _opts ->
        {:error, :timeout}
      end

      sample = Sample.new(input: "test", target: "answer") |> Sample.with_output("answer")
      assert {:error, :timeout} = LLMJudge.score(sample, generate_fn: generate_fn)
    end

    test "handles generate_fn returning nil content" do
      generate_fn = fn _messages, _opts ->
        {:ok, %{content: nil}}
      end

      sample = Sample.new(input: "test", target: "answer") |> Sample.with_output("answer")
      {:ok, score} = LLMJudge.score(sample, generate_fn: generate_fn)

      # Should default to incorrect when content is nil
      assert score.value == 0.0
      assert score.metadata.grade == :incorrect
    end

    test "case-insensitive grade parsing" do
      test_cases = [
        {"correct", :correct},
        {"CORRECT", :correct},
        {"Correct", :correct},
        {"incorrect", :incorrect},
        {"INCORRECT", :incorrect},
        {"Incorrect", :incorrect}
      ]

      for {response, expected_grade} <- test_cases do
        generate_fn = fn _messages, _opts ->
          {:ok, %{content: response}}
        end

        sample = Sample.new(input: "test", target: "answer") |> Sample.with_output("answer")
        {:ok, score} = LLMJudge.score(sample, generate_fn: generate_fn)

        assert score.metadata.grade == expected_grade
      end
    end
  end

  describe "scorer_id/0" do
    test "returns default ID" do
      assert LLMJudge.scorer_id() == "llm_judge"
    end
  end
end
