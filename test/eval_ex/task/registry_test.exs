defmodule EvalEx.Task.RegistryTest do
  use ExUnit.Case, async: false

  alias EvalEx.Task.Registry

  defmodule Task1 do
    use EvalEx.Task

    def task_id, do: "task_1"
    def name, do: "Task 1"
    def dataset, do: :test
    def scorers, do: []
  end

  defmodule Task2 do
    use EvalEx.Task

    def task_id, do: "task_2"
    def name, do: "Task 2"
    def dataset, do: :test
    def scorers, do: []
  end

  defmodule DecoratedTasks do
    use EvalEx.Task, decorator: true

    task example_task() do
      EvalEx.Task.new(id: "example_task", name: "Example Task", dataset: [])
    end

    task custom_task(opts), name: "decorated/custom" do
      EvalEx.Task.new(id: "custom_task", name: "Custom Task", dataset: [], metadata: opts)
    end
  end

  setup do
    # Start a fresh registry for each test
    {:ok, pid} = start_supervised({Registry, name: :"registry_#{:erlang.unique_integer()}"})
    {:ok, registry: pid}
  end

  describe "start_link/1" do
    test "starts registry with default name" do
      {:ok, pid} = Registry.start_link(name: :test_registry)
      assert Process.alive?(pid)
    end

    test "starts registry with custom name" do
      {:ok, pid} = Registry.start_link(name: :custom_registry)
      assert Process.alive?(pid)
    end
  end

  describe "register/1" do
    test "registers a task module", %{registry: registry} do
      assert :ok = GenServer.call(registry, {:register, Task1})
    end

    test "registers multiple task modules", %{registry: registry} do
      assert :ok = GenServer.call(registry, {:register, Task1})
      assert :ok = GenServer.call(registry, {:register, Task2})
    end

    test "overwrites existing task with same ID", %{registry: registry} do
      GenServer.call(registry, {:register, Task1})
      assert :ok = GenServer.call(registry, {:register, Task1})
    end
  end

  describe "get/1" do
    test "returns task module when found", %{registry: registry} do
      GenServer.call(registry, {:register, Task1})
      assert {:ok, Task1} = GenServer.call(registry, {:get, "task_1"})
    end

    test "returns error when task not found", %{registry: registry} do
      assert {:error, :not_found} = GenServer.call(registry, {:get, "nonexistent"})
    end

    test "retrieves correct task among multiple", %{registry: registry} do
      GenServer.call(registry, {:register, Task1})
      GenServer.call(registry, {:register, Task2})

      assert {:ok, Task1} = GenServer.call(registry, {:get, "task_1"})
      assert {:ok, Task2} = GenServer.call(registry, {:get, "task_2"})
    end
  end

  describe "list/0" do
    test "returns empty list when no tasks registered", %{registry: registry} do
      assert [] = GenServer.call(registry, :list)
    end

    test "returns list of task IDs", %{registry: registry} do
      GenServer.call(registry, {:register, Task1})
      GenServer.call(registry, {:register, Task2})

      task_ids = GenServer.call(registry, :list)
      assert "task_1" in task_ids
      assert "task_2" in task_ids
      assert length(task_ids) == 2
    end
  end

  describe "integration" do
    test "full workflow: register, list, get", %{registry: registry} do
      # Initially empty
      assert [] = GenServer.call(registry, :list)

      # Register tasks
      GenServer.call(registry, {:register, Task1})
      GenServer.call(registry, {:register, Task2})

      # List shows all tasks
      task_ids = GenServer.call(registry, :list)
      assert length(task_ids) == 2

      # Can retrieve each task
      assert {:ok, Task1} = GenServer.call(registry, {:get, "task_1"})
      assert {:ok, Task2} = GenServer.call(registry, {:get, "task_2"})

      # Unknown tasks return error
      assert {:error, :not_found} = GenServer.call(registry, {:get, "unknown"})
    end

    test "registers decorated tasks and creates task instances", %{registry: registry} do
      assert :ok = Registry.register_module(DecoratedTasks, registry: registry)

      task_ids = GenServer.call(registry, :list)
      assert "example_task" in task_ids
      assert "decorated/custom" in task_ids

      assert {:ok, %EvalEx.Task.Definition{} = defn} =
               GenServer.call(registry, {:get, "example_task"})

      assert defn.params == []

      assert {:ok, %EvalEx.Task{} = task} =
               Registry.create("example_task", registry: registry)

      assert task.id == "example_task"
      assert task.name == "Example Task"

      assert {:ok, %EvalEx.Task{} = task} =
               Registry.create("decorated/custom", [flag: true], registry: registry)

      assert task.metadata == [flag: true]
    end
  end
end
