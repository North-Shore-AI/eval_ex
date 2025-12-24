defmodule EvalEx.Task do
  @moduledoc """
  Evaluation task definition.

  Maps to inspect-ai's Task class. Defines a complete evaluation task
  including the dataset, scorers, and metadata.

  ## Usage

  Create a task struct directly:

      task = EvalEx.Task.new(
        id: "my_task",
        name: "My Evaluation Task",
        dataset: :scifact,
        scorers: [EvalEx.Scorer.ExactMatch]
      )

  Or implement as a module:

      defmodule MyTask do
        use EvalEx.Task

        @impl true
        def task_id, do: "my_task"

        @impl true
        def name, do: "My Evaluation Task"

        @impl true
        def dataset, do: :scifact

        @impl true
        def scorers, do: [EvalEx.Scorer.ExactMatch]

        # Optional
        @impl true
        def description, do: "Custom description"

        @impl true
        def metadata, do: %{version: "1.0"}
      end
  """

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          description: String.t(),
          dataset: atom() | [EvalEx.Sample.t()],
          scorers: [module()],
          metadata: map()
        }

  defstruct [:id, :name, :description, :dataset, scorers: [], metadata: %{}]

  @callback task_id() :: String.t()
  @callback name() :: String.t()
  @callback dataset() :: atom() | [EvalEx.Sample.t()]
  @callback scorers() :: [module()]
  @callback description() :: String.t()
  @callback metadata() :: map()

  @optional_callbacks [description: 0, metadata: 0]

  @doc """
  Creates a new task with the given options.

  ## Required Options

    * `:id` - Unique task identifier
    * `:name` - Human-readable task name
    * `:dataset` - Dataset atom or list of samples

  ## Optional Options

    * `:description` - Task description (default: "")
    * `:scorers` - List of scorer modules (default: [])
    * `:metadata` - Map of additional metadata (default: %{})

  ## Examples

      iex> EvalEx.Task.new(
      ...>   id: "test_task",
      ...>   name: "Test Task",
      ...>   dataset: :scifact
      ...> )
      %EvalEx.Task{id: "test_task", name: "Test Task", dataset: :scifact, ...}
  """
  def new(opts) do
    %__MODULE__{
      id: Keyword.fetch!(opts, :id),
      name: Keyword.fetch!(opts, :name),
      description: Keyword.get(opts, :description, ""),
      dataset: Keyword.fetch!(opts, :dataset),
      scorers: Keyword.get(opts, :scorers, []),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Use this module to implement a task as a behaviour.

  Automatically provides default implementations for optional callbacks.
  """
  defmacro __using__(_opts) do
    quote do
      @behaviour EvalEx.Task

      @doc """
      Returns the task description (optional).
      Default implementation returns empty string.
      """
      def description, do: ""

      @doc """
      Returns the task metadata (optional).
      Default implementation returns empty map.
      """
      def metadata, do: %{}

      defoverridable description: 0, metadata: 0
    end
  end
end
