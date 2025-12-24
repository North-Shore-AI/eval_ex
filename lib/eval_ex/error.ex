defmodule EvalEx.Error do
  @moduledoc """
  Error categorization for evaluation failures.

  Provides structured error handling for different types of failures
  that can occur during model evaluation.
  """

  @type category :: :hallucination | :factual | :formatting | :timeout | :parsing | :other

  @type t :: %__MODULE__{
          category: category(),
          message: String.t(),
          sample_id: String.t() | nil,
          details: map()
        }

  defstruct [:category, :message, :sample_id, details: %{}]

  @doc """
  Creates a new error with the given category and message.

  ## Options

    * `:sample_id` - Optional sample identifier
    * `:details` - Optional map of additional error details

  ## Examples

      iex> EvalEx.Error.new(:timeout, "Request timed out")
      %EvalEx.Error{category: :timeout, message: "Request timed out", sample_id: nil, details: %{}}

      iex> EvalEx.Error.new(:parsing, "Invalid JSON", sample_id: "s_123", details: %{line: 5})
      %EvalEx.Error{category: :parsing, message: "Invalid JSON", sample_id: "s_123", details: %{line: 5}}
  """
  def new(category, message, opts \\ []) do
    %__MODULE__{
      category: category,
      message: message,
      sample_id: Keyword.get(opts, :sample_id),
      details: Keyword.get(opts, :details, %{})
    }
  end

  @doc """
  Categorizes an error tuple into a standard category.

  ## Examples

      iex> EvalEx.Error.categorize({:error, :timeout})
      :timeout

      iex> EvalEx.Error.categorize({:error, {:json, "invalid"}})
      :parsing

      iex> EvalEx.Error.categorize({:error, :unknown})
      :other
  """
  def categorize(error) do
    cond do
      match?({:error, :timeout}, error) -> :timeout
      match?({:error, {:json, _}}, error) -> :parsing
      true -> :other
    end
  end
end
