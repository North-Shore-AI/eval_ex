defmodule EvalEx.Task.Registry do
  @moduledoc """
  Registry for discovering evaluation tasks.

  Provides a simple GenServer-based registry for task discovery,
  similar to inspect-ai's @task decorator functionality.

  ## Usage

      # Start the registry (usually in your supervision tree)
      {:ok, _pid} = EvalEx.Task.Registry.start_link()

      # Register a task module
      EvalEx.Task.Registry.register(MyTask)

      # Get a task by ID
      {:ok, task_module} = EvalEx.Task.Registry.get("my_task")

      # List all registered task IDs
      task_ids = EvalEx.Task.Registry.list()
  """

  use GenServer

  @doc """
  Starts the registry GenServer.

  ## Options

    * `:name` - Registry name (default: `EvalEx.Task.Registry`)

  ## Examples

      {:ok, pid} = EvalEx.Task.Registry.start_link()
      {:ok, pid} = EvalEx.Task.Registry.start_link(name: :my_registry)
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, Keyword.put_new(opts, :name, __MODULE__))
  end

  @doc """
  Registers a task module in the registry.

  The task module must implement the `EvalEx.Task` behaviour.

  ## Examples

      EvalEx.Task.Registry.register(MyTask)
      # => :ok
  """
  def register(task_module), do: GenServer.call(__MODULE__, {:register, task_module})

  @doc """
  Gets a task module by its ID.

  ## Examples

      EvalEx.Task.Registry.get("my_task")
      # => {:ok, MyTask}

      EvalEx.Task.Registry.get("nonexistent")
      # => {:error, :not_found}
  """
  def get(task_id), do: GenServer.call(__MODULE__, {:get, task_id})

  @doc """
  Lists all registered task IDs.

  ## Examples

      EvalEx.Task.Registry.list()
      # => ["task_1", "task_2", "task_3"]
  """
  def list, do: GenServer.call(__MODULE__, :list)

  @impl true
  def init(_), do: {:ok, %{}}

  @impl true
  def handle_call({:register, module}, _from, state) do
    {:reply, :ok, Map.put(state, module.task_id(), module)}
  end

  @impl true
  def handle_call({:get, id}, _from, state) do
    case Map.get(state, id) do
      nil -> {:reply, {:error, :not_found}, state}
      mod -> {:reply, {:ok, mod}, state}
    end
  end

  @impl true
  def handle_call(:list, _from, state), do: {:reply, Map.keys(state), state}
end
