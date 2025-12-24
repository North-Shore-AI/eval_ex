defmodule EvalEx.SampleTest do
  use ExUnit.Case, async: true

  alias EvalEx.Sample

  describe "new/1" do
    test "creates sample with required input field" do
      sample = Sample.new(input: "What is 2+2?")

      assert sample.input == "What is 2+2?"
      assert sample.target == ""
      assert sample.choices == nil
      assert sample.metadata == %{}
      assert sample.model_output == nil
      assert sample.scores == %{}
      assert sample.error == nil
      assert is_binary(sample.id)
    end

    test "creates sample with all fields" do
      sample =
        Sample.new(
          id: "sample_1",
          input: "What is 2+2?",
          target: "4",
          choices: ["3", "4", "5"],
          metadata: %{difficulty: "easy"}
        )

      assert sample.id == "sample_1"
      assert sample.input == "What is 2+2?"
      assert sample.target == "4"
      assert sample.choices == ["3", "4", "5"]
      assert sample.metadata == %{difficulty: "easy"}
    end

    test "generates unique ID when not provided" do
      sample1 = Sample.new(input: "test1")
      sample2 = Sample.new(input: "test2")

      assert is_binary(sample1.id)
      assert is_binary(sample2.id)
      assert sample1.id != sample2.id
    end

    test "accepts chat-style input as list of maps" do
      messages = [
        %{role: "system", content: "You are a helpful assistant"},
        %{role: "user", content: "Hello"}
      ]

      sample = Sample.new(input: messages)

      assert sample.input == messages
    end

    test "accepts multiple targets as list" do
      sample =
        Sample.new(
          input: "What is the capital of France?",
          target: ["Paris", "paris"]
        )

      assert sample.target == ["Paris", "paris"]
    end
  end

  describe "with_output/2" do
    test "adds model output to sample" do
      sample = Sample.new(input: "test")
      updated = Sample.with_output(sample, "response")

      assert updated.model_output == "response"
      assert updated.input == "test"
    end

    test "replaces existing output" do
      sample = Sample.new(input: "test") |> Sample.with_output("first")
      updated = Sample.with_output(sample, "second")

      assert updated.model_output == "second"
    end
  end

  describe "with_score/3" do
    test "adds score to sample" do
      sample = Sample.new(input: "test")
      updated = Sample.with_score(sample, :accuracy, 0.95)

      assert updated.scores == %{accuracy: 0.95}
    end

    test "adds multiple scores" do
      sample = Sample.new(input: "test")

      updated =
        sample
        |> Sample.with_score(:accuracy, 0.95)
        |> Sample.with_score(:fluency, 0.88)

      assert updated.scores == %{accuracy: 0.95, fluency: 0.88}
    end

    test "replaces existing score with same name" do
      sample = Sample.new(input: "test")

      updated =
        sample
        |> Sample.with_score(:accuracy, 0.95)
        |> Sample.with_score(:accuracy, 0.90)

      assert updated.scores == %{accuracy: 0.90}
    end
  end

  describe "with_error/2" do
    test "adds error to sample" do
      sample = Sample.new(input: "test")
      error = %{category: :timeout, message: "Request timed out"}
      updated = Sample.with_error(sample, error)

      assert updated.error == error
    end

    test "replaces existing error" do
      sample = Sample.new(input: "test")
      error1 = %{category: :timeout, message: "Timeout"}
      error2 = %{category: :parsing, message: "Parse error"}

      updated =
        sample
        |> Sample.with_error(error1)
        |> Sample.with_error(error2)

      assert updated.error == error2
    end
  end

  describe "integration" do
    test "can build up sample with multiple operations" do
      sample =
        Sample.new(
          id: "s_1",
          input: "What is 2+2?",
          target: "4",
          metadata: %{difficulty: "easy"}
        )
        |> Sample.with_output("4")
        |> Sample.with_score(:exact_match, 1.0)
        |> Sample.with_score(:llm_judge, 1.0)

      assert sample.id == "s_1"
      assert sample.input == "What is 2+2?"
      assert sample.target == "4"
      assert sample.model_output == "4"
      assert sample.scores == %{exact_match: 1.0, llm_judge: 1.0}
      assert sample.metadata == %{difficulty: "easy"}
    end

    test "can track error state" do
      sample =
        Sample.new(input: "test")
        |> Sample.with_output("response")
        |> Sample.with_error(%{category: :timeout, message: "Timed out"})

      assert sample.model_output == "response"
      assert sample.error == %{category: :timeout, message: "Timed out"}
    end
  end
end
