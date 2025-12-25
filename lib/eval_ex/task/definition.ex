defmodule EvalEx.Task.Definition do
  @moduledoc """
  Metadata for task definitions registered via the @task-style macro.
  """

  alias EvalEx.Task

  @type t :: %__MODULE__{
          name: String.t(),
          module: module(),
          function: atom(),
          arity: non_neg_integer(),
          params: [String.t()],
          attribs: map(),
          file: String.t() | nil,
          run_dir: String.t() | nil
        }

  defstruct [:name, :module, :function, :arity, :params, :attribs, :file, :run_dir]

  @doc """
  Invoke the task definition with provided args.
  """
  @spec invoke(t(), list() | map() | keyword()) :: Task.t()
  def invoke(%__MODULE__{module: module, function: function, arity: arity}, args) do
    apply(module, function, normalize_args(args, arity))
  end

  defp normalize_args(args, 0) when args in [[], nil], do: []

  defp normalize_args(args, 1) when is_list(args) do
    if Keyword.keyword?(args), do: [args], else: args
  end

  defp normalize_args(args, 1) when is_map(args), do: [args]

  defp normalize_args(args, arity) when is_list(args) and length(args) == arity, do: args

  defp normalize_args(args, _arity), do: [args]
end
