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

    test "returns 1.0 when LLM grades as correct" do
      generate_fn = fn _messages, _opts ->
        {:ok, %{content: "Reasoning...\nGRADE: C"}}
      end

      sample = Sample.new(input: "What is 2+2?", target: "4") |> Sample.with_output("4")
      {:ok, score} = LLMJudge.score(sample, generate_fn: generate_fn)

      assert score.value == 1.0
      assert score.answer == "4"
      assert score.metadata.grade == :correct
    end

    test "returns 0.0 when LLM grades as incorrect" do
      generate_fn = fn _messages, _opts ->
        {:ok, %{content: "GRADE: I"}}
      end

      sample = Sample.new(input: "What is 2+2?", target: "4") |> Sample.with_output("5")
      {:ok, score} = LLMJudge.score(sample, generate_fn: generate_fn)

      assert score.value == 0.0
      assert score.answer == "5"
      assert score.metadata.grade == :incorrect
    end

    test "returns 0.5 for partial credit when enabled" do
      generate_fn = fn _messages, _opts ->
        {:ok, %{content: "GRADE: P"}}
      end

      sample = Sample.new(input: "test", target: "answer") |> Sample.with_output("partial")
      {:ok, score} = LLMJudge.score(sample, generate_fn: generate_fn, partial_credit: true)

      assert score.value == 0.5
      assert score.metadata.grade == :partial
    end

    test "treats partial credit as incorrect when disabled" do
      generate_fn = fn _messages, _opts ->
        {:ok, %{content: "GRADE: P"}}
      end

      sample = Sample.new(input: "test", target: "answer") |> Sample.with_output("partial")
      {:ok, score} = LLMJudge.score(sample, generate_fn: generate_fn, partial_credit: false)

      assert score.value == 0.0
      assert score.metadata.grade == :incorrect
    end

    test "defaults to incorrect when grade pattern is missing" do
      generate_fn = fn _messages, _opts ->
        {:ok, %{content: "Unclear response"}}
      end

      sample = Sample.new(input: "test", target: "answer") |> Sample.with_output("maybe")
      {:ok, score} = LLMJudge.score(sample, generate_fn: generate_fn)

      assert score.value == 0.0
      assert score.metadata.grade == :incorrect
    end

    test "builds prompt with question, criterion, and answer" do
      {:ok, captured_messages} = Agent.start_link(fn -> nil end)

      generate_fn = fn messages, _opts ->
        Agent.update(captured_messages, fn _ -> messages end)
        {:ok, %{content: "GRADE: C"}}
      end

      sample = Sample.new(input: "What is 2+2?", target: "4") |> Sample.with_output("4")
      {:ok, _score} = LLMJudge.score(sample, generate_fn: generate_fn)

      [%{role: "user", content: prompt}] = Agent.get(captured_messages, & &1)
      assert prompt =~ "What is 2+2?"
      assert prompt =~ "4"
    end

    test "supports custom prompt template" do
      {:ok, captured_messages} = Agent.start_link(fn -> nil end)

      generate_fn = fn messages, _opts ->
        Agent.update(captured_messages, fn _ -> messages end)
        {:ok, %{content: "GRADE: C"}}
      end

      custom_prompt = "Q: {input}\nA: {response}\nExpected: {target}\nGrade:"

      sample = Sample.new(input: "test", target: "answer") |> Sample.with_output("answer")

      {:ok, _score} =
        LLMJudge.score(sample, generate_fn: generate_fn, prompt: custom_prompt)

      [%{content: prompt}] = Agent.get(captured_messages, & &1)
      assert prompt =~ "Q: test"
      assert prompt =~ "A: answer"
      assert prompt =~ "Expected: answer"
    end

    test "passes model or model_role to generate_fn" do
      generate_fn = fn _messages, opts ->
        send(self(), {:opts, opts})
        {:ok, %{content: "GRADE: C"}}
      end

      sample = Sample.new(input: "test", target: "answer") |> Sample.with_output("answer")

      {:ok, _score} =
        LLMJudge.score(sample, generate_fn: generate_fn, model: "grader-model")

      assert_receive {:opts, opts}
      assert opts[:model] == "grader-model"
    end

    test "propagates generate_fn errors" do
      generate_fn = fn _messages, _opts ->
        {:error, :timeout}
      end

      sample = Sample.new(input: "test", target: "answer") |> Sample.with_output("answer")
      assert {:error, :timeout} = LLMJudge.score(sample, generate_fn: generate_fn)
    end

    test "handles nil model_output" do
      generate_fn = fn _messages, _opts ->
        {:ok, %{content: "GRADE: I"}}
      end

      sample = Sample.new(input: "test", target: "answer")
      {:ok, score} = LLMJudge.score(sample, generate_fn: generate_fn)

      assert score.value == 0.0
      assert score.answer == nil
    end

    test "grade parsing is case-insensitive" do
      test_cases = [
        {"grade: c", :correct},
        {"GRADE: C", :correct},
        {"grade: p", :partial},
        {"GRADE: I", :incorrect}
      ]

      for {response, expected_grade} <- test_cases do
        generate_fn = fn _messages, _opts ->
          {:ok, %{content: response}}
        end

        sample = Sample.new(input: "test", target: "answer") |> Sample.with_output("answer")
        {:ok, score} = LLMJudge.score(sample, generate_fn: generate_fn, partial_credit: true)

        assert score.metadata.grade == expected_grade
      end
    end
  end

  describe "scorer_id/0" do
    test "returns default ID" do
      assert LLMJudge.scorer_id() == "llm_judge"
    end
  end

  describe "metrics/0" do
    test "returns accuracy and stderr" do
      assert LLMJudge.metrics() == [:accuracy, :stderr]
    end
  end
end
