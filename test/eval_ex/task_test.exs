defmodule EvalEx.TaskTest do
  use ExUnit.Case, async: true

  alias EvalEx.{Task, Sample, Scorer.ExactMatch}

  describe "new/1" do
    test "creates task with required fields" do
      task =
        Task.new(
          id: "test_task",
          name: "Test Task",
          dataset: :test_dataset
        )

      assert task.id == "test_task"
      assert task.name == "Test Task"
      assert task.dataset == :test_dataset
      assert task.description == ""
      assert task.scorers == []
      assert task.metadata == %{}
    end

    test "creates task with all fields" do
      samples = [
        Sample.new(input: "test1", target: "answer1"),
        Sample.new(input: "test2", target: "answer2")
      ]

      task =
        Task.new(
          id: "full_task",
          name: "Full Task",
          description: "A complete task",
          dataset: samples,
          scorers: [ExactMatch],
          metadata: %{version: "1.0", difficulty: "easy"}
        )

      assert task.id == "full_task"
      assert task.name == "Full Task"
      assert task.description == "A complete task"
      assert task.dataset == samples
      assert task.scorers == [ExactMatch]
      assert task.metadata == %{version: "1.0", difficulty: "easy"}
    end

    test "requires id field" do
      assert_raise KeyError, fn ->
        Task.new(name: "Test", dataset: :test)
      end
    end

    test "requires name field" do
      assert_raise KeyError, fn ->
        Task.new(id: "test", dataset: :test)
      end
    end

    test "requires dataset field" do
      assert_raise KeyError, fn ->
        Task.new(id: "test", name: "Test")
      end
    end

    test "accepts dataset as atom" do
      task = Task.new(id: "test", name: "Test", dataset: :scifact)
      assert task.dataset == :scifact
    end

    test "accepts dataset as list of samples" do
      samples = [Sample.new(input: "test")]
      task = Task.new(id: "test", name: "Test", dataset: samples)
      assert task.dataset == samples
    end

    test "accepts multiple scorers" do
      task =
        Task.new(
          id: "test",
          name: "Test",
          dataset: :test,
          scorers: [ExactMatch, EvalEx.Scorer.LLMJudge]
        )

      assert task.scorers == [ExactMatch, EvalEx.Scorer.LLMJudge]
    end
  end

  describe "behaviour implementation" do
    defmodule TestTask do
      use Task

      @impl true
      def task_id, do: "test_task"

      @impl true
      def name, do: "Test Task"

      @impl true
      def dataset, do: :test_dataset

      @impl true
      def scorers, do: [ExactMatch]
    end

    defmodule MinimalTask do
      use Task

      @impl true
      def task_id, do: "minimal"

      @impl true
      def name, do: "Minimal"

      @impl true
      def dataset, do: []

      @impl true
      def scorers, do: []
    end

    defmodule CustomTask do
      use Task

      @impl true
      def task_id, do: "custom"

      @impl true
      def name, do: "Custom"

      @impl true
      def dataset, do: :custom

      @impl true
      def scorers, do: []

      @impl true
      def description, do: "Custom description"

      @impl true
      def metadata, do: %{custom: true}
    end

    test "implements required callbacks" do
      assert TestTask.task_id() == "test_task"
      assert TestTask.name() == "Test Task"
      assert TestTask.dataset() == :test_dataset
      assert TestTask.scorers() == [ExactMatch]
    end

    test "provides default description" do
      assert MinimalTask.description() == ""
    end

    test "provides default metadata" do
      assert MinimalTask.metadata() == %{}
    end

    test "allows overriding description" do
      assert CustomTask.description() == "Custom description"
    end

    test "allows overriding metadata" do
      assert CustomTask.metadata() == %{custom: true}
    end
  end
end
