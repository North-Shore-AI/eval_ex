defmodule EvalEx.Sample do
  @moduledoc """
  Rich sample with per-sample metadata.

  Maps to inspect-ai's Sample class. Represents a single evaluation
  example with input, expected output (target), model output, scores,
  and error tracking.
  """

  @type t :: %__MODULE__{
          id: String.t() | integer(),
          input: String.t() | [map()],
          target: String.t() | [String.t()],
          choices: [String.t()] | nil,
          metadata: map(),
          model_output: String.t() | nil,
          scores: map(),
          error: map() | nil
        }

  defstruct [:id, :input, :target, :choices, :model_output, :error, metadata: %{}, scores: %{}]

  @doc """
  Creates a new sample with the given options.

  ## Required Options

    * `:input` - The input to the model (string or list of message maps)

  ## Optional Options

    * `:id` - Unique identifier (auto-generated if not provided)
    * `:target` - Expected output (string or list of strings)
    * `:choices` - List of multiple choice options
    * `:metadata` - Map of additional metadata

  ## Examples

      iex> EvalEx.Sample.new(input: "What is 2+2?")
      %EvalEx.Sample{input: "What is 2+2?", target: "", ...}

      iex> EvalEx.Sample.new(
      ...>   id: "sample_1",
      ...>   input: "What is 2+2?",
      ...>   target: "4",
      ...>   choices: ["3", "4", "5"],
      ...>   metadata: %{difficulty: "easy"}
      ...> )
      %EvalEx.Sample{id: "sample_1", input: "What is 2+2?", target: "4", ...}
  """
  def new(opts) do
    %__MODULE__{
      id: Keyword.get(opts, :id, generate_id()),
      input: Keyword.fetch!(opts, :input),
      target: Keyword.get(opts, :target, ""),
      choices: Keyword.get(opts, :choices),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  @doc """
  Adds model output to the sample.

  ## Examples

      iex> sample = EvalEx.Sample.new(input: "test")
      iex> EvalEx.Sample.with_output(sample, "response")
      %EvalEx.Sample{input: "test", model_output: "response", ...}
  """
  def with_output(sample, output), do: %{sample | model_output: output}

  @doc """
  Adds a score to the sample.

  ## Examples

      iex> sample = EvalEx.Sample.new(input: "test")
      iex> EvalEx.Sample.with_score(sample, :accuracy, 0.95)
      %EvalEx.Sample{scores: %{accuracy: 0.95}, ...}
  """
  def with_score(sample, name, score), do: %{sample | scores: Map.put(sample.scores, name, score)}

  @doc """
  Adds an error to the sample.

  ## Examples

      iex> sample = EvalEx.Sample.new(input: "test")
      iex> EvalEx.Sample.with_error(sample, %{category: :timeout, message: "Timed out"})
      %EvalEx.Sample{error: %{category: :timeout, message: "Timed out"}, ...}
  """
  def with_error(sample, error), do: %{sample | error: error}

  defp generate_id, do: :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
end
