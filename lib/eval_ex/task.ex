defmodule EvalEx.Task do
  @moduledoc """
  Evaluation task definition.

  Maps to inspect-ai's Task class. Defines evaluation datasets, solvers,
  scorers, and limits. Tasks can be constructed as structs, module behaviours,
  or with the `task/2` macro for registry-friendly definitions.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          display_name: String.t() | nil,
          description: String.t(),
          dataset: atom() | [EvalEx.Sample.t()] | CrucibleDatasets.Dataset.t(),
          setup: term() | nil,
          solver: term() | nil,
          cleanup: term() | nil,
          scorer: module() | nil,
          scorers: [module()],
          metrics: [atom()] | nil,
          model: term() | nil,
          config: map(),
          model_roles: map(),
          sandbox: term() | nil,
          approval: term() | nil,
          epochs: term() | nil,
          fail_on_error: term() | nil,
          continue_on_fail: term() | nil,
          message_limit: pos_integer() | nil,
          token_limit: pos_integer() | nil,
          time_limit: pos_integer() | nil,
          working_limit: pos_integer() | nil,
          version: non_neg_integer() | String.t(),
          metadata: map()
        }

  defstruct [
    :id,
    :name,
    :display_name,
    :description,
    :dataset,
    :setup,
    :solver,
    :cleanup,
    :scorer,
    scorers: [],
    metrics: nil,
    model: nil,
    config: %{},
    model_roles: %{},
    sandbox: nil,
    approval: nil,
    epochs: nil,
    fail_on_error: nil,
    continue_on_fail: nil,
    message_limit: nil,
    token_limit: nil,
    time_limit: nil,
    working_limit: nil,
    version: 0,
    metadata: %{}
  ]

  @callback task_id() :: String.t()
  @callback name() :: String.t()
  @callback dataset() :: atom() | [EvalEx.Sample.t()] | CrucibleDatasets.Dataset.t()
  @callback scorers() :: [module()]
  @callback scorer() :: module() | nil
  @callback description() :: String.t()
  @callback metadata() :: map()
  @callback display_name() :: String.t() | nil
  @callback version() :: non_neg_integer() | String.t()
  @callback solver() :: term() | nil
  @callback metrics() :: [atom()] | nil
  @callback model() :: term() | nil
  @callback config() :: map()
  @callback model_roles() :: map()
  @callback sandbox() :: term() | nil
  @callback approval() :: term() | nil
  @callback epochs() :: term() | nil
  @callback fail_on_error() :: term() | nil
  @callback continue_on_fail() :: term() | nil
  @callback message_limit() :: pos_integer() | nil
  @callback token_limit() :: pos_integer() | nil
  @callback time_limit() :: pos_integer() | nil
  @callback working_limit() :: pos_integer() | nil
  @callback setup() :: term() | nil
  @callback cleanup() :: term() | nil

  @optional_callbacks [
    scorers: 0,
    scorer: 0,
    description: 0,
    metadata: 0,
    display_name: 0,
    version: 0,
    solver: 0,
    metrics: 0,
    model: 0,
    config: 0,
    model_roles: 0,
    sandbox: 0,
    approval: 0,
    epochs: 0,
    fail_on_error: 0,
    continue_on_fail: 0,
    message_limit: 0,
    token_limit: 0,
    time_limit: 0,
    working_limit: 0,
    setup: 0,
    cleanup: 0
  ]

  @doc """
  Creates a new task with the given options.

  ## Required Options

    * `:id` - Unique task identifier
    * `:name` - Human-readable task name
    * `:dataset` - Dataset atom, list of samples, or CrucibleDatasets.Dataset

  ## Optional Options

    * `:display_name` - Display name (defaults to name)
    * `:description` - Task description (default: "")
    * `:scorers` - List of scorer modules (default: [])
    * `:scorer` - Single scorer module
    * `:metrics` - Metrics identifiers for aggregation
    * `:model` - Default model (optional)
    * `:config` - Model config map
    * `:model_roles` - Named model roles
    * `:message_limit`, `:token_limit`, `:time_limit`, `:working_limit` - Limits
    * `:version` - Task version
    * `:metadata` - Arbitrary metadata
  """
  def new(opts) do
    id = Keyword.fetch!(opts, :id)
    name = Keyword.fetch!(opts, :name)
    dataset = Keyword.fetch!(opts, :dataset)

    scorer = Keyword.get(opts, :scorer)
    scorers = Keyword.get(opts, :scorers, if(scorer, do: [scorer], else: []))

    %__MODULE__{
      id: id,
      name: name,
      display_name: Keyword.get(opts, :display_name, name),
      description: Keyword.get(opts, :description, ""),
      dataset: dataset,
      setup: Keyword.get(opts, :setup),
      solver: Keyword.get(opts, :solver),
      cleanup: Keyword.get(opts, :cleanup),
      scorer: scorer || List.first(scorers),
      scorers: scorers,
      metrics: Keyword.get(opts, :metrics),
      model: Keyword.get(opts, :model),
      config: Keyword.get(opts, :config, %{}),
      model_roles: Keyword.get(opts, :model_roles, %{}),
      sandbox: Keyword.get(opts, :sandbox),
      approval: Keyword.get(opts, :approval),
      epochs: Keyword.get(opts, :epochs),
      fail_on_error: Keyword.get(opts, :fail_on_error),
      continue_on_fail: Keyword.get(opts, :continue_on_fail),
      message_limit: Keyword.get(opts, :message_limit),
      token_limit: Keyword.get(opts, :token_limit),
      time_limit: Keyword.get(opts, :time_limit),
      working_limit: Keyword.get(opts, :working_limit),
      version: Keyword.get(opts, :version, 0),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Build a task struct from a module implementing EvalEx.Task behaviour.
  """
  def from_module(module) when is_atom(module) do
    scorers = if function_exported?(module, :scorers, 0), do: module.scorers(), else: []
    scorer = if function_exported?(module, :scorer, 0), do: module.scorer(), else: nil

    display_name =
      if function_exported?(module, :display_name, 0) do
        module.display_name()
      else
        nil
      end

    %__MODULE__{
      id: module.task_id(),
      name: module.name(),
      display_name: display_name || module.name(),
      description: safe_call(module, :description, ""),
      dataset: module.dataset(),
      setup: safe_call(module, :setup, nil),
      solver: safe_call(module, :solver, nil),
      cleanup: safe_call(module, :cleanup, nil),
      scorer: scorer || List.first(scorers),
      scorers: scorers,
      metrics: safe_call(module, :metrics, nil),
      model: safe_call(module, :model, nil),
      config: safe_call(module, :config, %{}),
      model_roles: safe_call(module, :model_roles, %{}),
      sandbox: safe_call(module, :sandbox, nil),
      approval: safe_call(module, :approval, nil),
      epochs: safe_call(module, :epochs, nil),
      fail_on_error: safe_call(module, :fail_on_error, nil),
      continue_on_fail: safe_call(module, :continue_on_fail, nil),
      message_limit: safe_call(module, :message_limit, nil),
      token_limit: safe_call(module, :token_limit, nil),
      time_limit: safe_call(module, :time_limit, nil),
      working_limit: safe_call(module, :working_limit, nil),
      version: safe_call(module, :version, 0),
      metadata: safe_call(module, :metadata, %{})
    }
  end

  @doc """
  Define a task function and register metadata for the task registry.
  """
  defmacro task(fun_head, opts \\ [], do: body) do
    {fun_name, _meta, args} = fun_head
    task_name = Keyword.get(opts, :name, Atom.to_string(fun_name))
    attribs = opts |> Keyword.delete(:name) |> Enum.into(%{})
    params = Enum.map(args || [], &param_name/1)
    file = __CALLER__.file
    run_dir = Path.dirname(file)

    quote do
      def unquote(fun_head) do
        unquote(body)
      end

      @eval_ex_tasks %EvalEx.Task.Definition{
        name: unquote(task_name),
        module: __MODULE__,
        function: unquote(fun_name),
        arity: unquote(length(args || [])),
        params: unquote(params),
        attribs: unquote(Macro.escape(attribs)),
        file: unquote(file),
        run_dir: unquote(run_dir)
      }
    end
  end

  defmacro __before_compile__(env) do
    tasks = Module.get_attribute(env.module, :eval_ex_tasks) || []

    quote do
      def __eval_ex_tasks__, do: unquote(Macro.escape(tasks))
    end
  end

  @doc """
  Use this module to implement a task as a behaviour.
  """
  defmacro __using__(opts) do
    quote bind_quoted: [opts: opts] do
      if !Keyword.get(opts, :decorator, false) do
        @behaviour EvalEx.Task

        def description, do: ""
        def metadata, do: %{}
        def display_name, do: nil
        def version, do: 0
        def solver, do: nil
        def scorer, do: nil
        def scorers, do: []
        def metrics, do: nil
        def model, do: nil
        def config, do: %{}
        def model_roles, do: %{}
        def sandbox, do: nil
        def approval, do: nil
        def epochs, do: nil
        def fail_on_error, do: nil
        def continue_on_fail, do: nil
        def message_limit, do: nil
        def token_limit, do: nil
        def time_limit, do: nil
        def working_limit, do: nil
        def setup, do: nil
        def cleanup, do: nil

        defoverridable description: 0,
                       metadata: 0,
                       display_name: 0,
                       version: 0,
                       solver: 0,
                       scorer: 0,
                       scorers: 0,
                       metrics: 0,
                       model: 0,
                       config: 0,
                       model_roles: 0,
                       sandbox: 0,
                       approval: 0,
                       epochs: 0,
                       fail_on_error: 0,
                       continue_on_fail: 0,
                       message_limit: 0,
                       token_limit: 0,
                       time_limit: 0,
                       working_limit: 0,
                       setup: 0,
                       cleanup: 0
      end

      Module.register_attribute(__MODULE__, :eval_ex_tasks, accumulate: true)
      import EvalEx.Task, only: [task: 2, task: 3]
      @before_compile EvalEx.Task
    end
  end

  defp param_name({:\\, _, [param, _default]}), do: param_name(param)
  defp param_name({name, _, _}) when is_atom(name), do: Atom.to_string(name)
  defp param_name(other), do: Macro.to_string(other)

  defp safe_call(module, fun, default) do
    if function_exported?(module, fun, 0) do
      apply(module, fun, [])
    else
      default
    end
  end
end
