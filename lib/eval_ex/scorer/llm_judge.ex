defmodule EvalEx.Scorer.LLMJudge do
  @moduledoc """
  LLM-as-judge scorer. Maps to inspect-ai's model_graded_qa.

  NOTE: Does not call LLMs directly. Requires a generate_fn in opts.
  The actual LLM backend is injected by the caller.

  ## Usage

      generate_fn = fn messages, opts ->
        # Call your LLM backend here
        {:ok, %{content: "CORRECT"}}
      end

      sample = EvalEx.Sample.new(input: "What is 2+2?", target: "4")
        |> EvalEx.Sample.with_output("4")

      {:ok, score} = EvalEx.Scorer.LLMJudge.score(sample, generate_fn: generate_fn)
      # => %{value: 1.0, answer: "4", explanation: "CORRECT", metadata: %{grade: :correct}}

  ## Custom Prompt

      custom_prompt = \"\"\"
      Question: {input}
      Expected: {target}
      Response: {response}

      Is the response correct? Answer CORRECT or INCORRECT.
      \"\"\"

      {:ok, score} = EvalEx.Scorer.LLMJudge.score(
        sample,
        generate_fn: generate_fn,
        prompt: custom_prompt
      )
  """

  use EvalEx.Scorer

  @default_prompt """
  Question: {input}
  Expected: {target}
  Response: {response}

  Grade as CORRECT or INCORRECT.
  """

  @impl true
  def score(sample, opts \\ []) do
    generate_fn = Keyword.fetch!(opts, :generate_fn)
    prompt_template = Keyword.get(opts, :prompt, @default_prompt)

    prompt =
      prompt_template
      |> String.replace("{input}", to_string(sample.input))
      |> String.replace("{target}", to_string(sample.target))
      |> String.replace("{response}", sample.model_output || "")

    case generate_fn.([%{role: "user", content: prompt}], opts) do
      {:ok, response} ->
        grade = parse_grade(response.content)

        {:ok,
         %{
           value: if(grade == :correct, do: 1.0, else: 0.0),
           answer: sample.model_output,
           explanation: response.content,
           metadata: %{grade: grade}
         }}

      error ->
        error
    end
  end

  defp parse_grade(text) do
    upper = String.upcase(text || "")

    cond do
      String.contains?(upper, "INCORRECT") -> :incorrect
      String.contains?(upper, "CORRECT") -> :correct
      true -> :incorrect
    end
  end
end
