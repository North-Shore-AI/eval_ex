defmodule EvalEx.Scorer.ExactMatch do
  @moduledoc """
  Exact string match scorer.

  Normalizes both the model output and target(s) by:
  - Converting to lowercase
  - Trimming whitespace

  Supports matching against multiple targets (returns 1.0 if any target matches).

  ## Examples

      iex> sample = EvalEx.Sample.new(input: "test", target: "answer")
      ...>   |> EvalEx.Sample.with_output("answer")
      iex> {:ok, score} = EvalEx.Scorer.ExactMatch.score(sample)
      iex> score.value
      1.0

      iex> sample = EvalEx.Sample.new(input: "test", target: "ANSWER")
      ...>   |> EvalEx.Sample.with_output("  answer  ")
      iex> {:ok, score} = EvalEx.Scorer.ExactMatch.score(sample)
      iex> score.value
      1.0

      iex> sample = EvalEx.Sample.new(input: "test", target: ["option1", "option2"])
      ...>   |> EvalEx.Sample.with_output("option2")
      iex> {:ok, score} = EvalEx.Scorer.ExactMatch.score(sample)
      iex> score.value
      1.0
  """

  use EvalEx.Scorer

  @impl true
  def score(sample, _opts \\ []) do
    output = sample.model_output || ""
    targets = List.wrap(sample.target)

    matched = Enum.any?(targets, &(normalize(&1) == normalize(output)))

    {:ok,
     %{
       value: if(matched, do: 1.0, else: 0.0),
       answer: output,
       explanation: nil,
       metadata: %{}
     }}
  end

  defp normalize(s), do: s |> to_string() |> String.downcase() |> String.trim()
end
