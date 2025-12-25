defmodule EvalEx.Scorer.LLMJudge do
  @moduledoc """
  LLM-as-judge scorer. Maps to inspect-ai's model_graded_qa.

  NOTE: Does not call LLMs directly. Requires a generate_fn in opts.
  The actual LLM backend is injected by the caller.
  """

  use EvalEx.Scorer

  @default_template """
  You are assessing a submitted answer on a given task based on a criterion. Here is the data:

  [BEGIN DATA]
  ***
  [Task]: {question}
  ***
  [Submission]: {answer}
  ***
  [Criterion]: {criterion}
  ***
  [END DATA]

  Does the submission meet the criterion?

  {instructions}
  """

  @default_grade_pattern ~r/(?i)GRADE\s*:\s*([CPI])/m

  @impl true
  def metrics, do: [:accuracy, :stderr]

  @impl true
  def score(sample, opts \\ []) do
    generate_fn = Keyword.fetch!(opts, :generate_fn)
    partial_credit = Keyword.get(opts, :partial_credit, false)
    instructions = Keyword.get(opts, :instructions, default_instructions(partial_credit))
    grade_pattern = Keyword.get(opts, :grade_pattern, @default_grade_pattern)

    prompt =
      if Keyword.has_key?(opts, :prompt) do
        build_legacy_prompt(sample, Keyword.fetch!(opts, :prompt))
      else
        template = Keyword.get(opts, :template, @default_template)
        build_prompt(sample, template, instructions)
      end

    generate_opts = build_generate_opts(opts)

    case generate_fn.([%{role: "user", content: prompt}], generate_opts) do
      {:ok, response} ->
        grade = parse_grade(response.content, grade_pattern, partial_credit)

        {:ok,
         %{
           value: grade.value,
           answer: sample.model_output,
           explanation: response.content,
           metadata: %{grade: grade.label}
         }}

      error ->
        error
    end
  end

  defp build_prompt(sample, template, instructions) do
    template
    |> String.replace("{question}", to_string(sample.input))
    |> String.replace("{criterion}", to_string(sample.target))
    |> String.replace("{answer}", to_string(sample.model_output || ""))
    |> String.replace("{instructions}", instructions)
  end

  defp build_legacy_prompt(sample, template) do
    template
    |> String.replace("{input}", to_string(sample.input))
    |> String.replace("{target}", to_string(sample.target))
    |> String.replace("{response}", to_string(sample.model_output || ""))
  end

  defp parse_grade(text, pattern, partial_credit) do
    content = to_string(text || "")

    case Regex.run(pattern, content) do
      [_, letter | _] ->
        normalize_grade(letter, partial_credit)

      _ ->
        %{value: 0.0, label: :incorrect}
    end
  end

  defp normalize_grade(letter, partial_credit) do
    case String.upcase(letter) do
      "C" ->
        %{value: 1.0, label: :correct}

      "P" ->
        if partial_credit do
          %{value: 0.5, label: :partial}
        else
          %{value: 0.0, label: :incorrect}
        end

      _ ->
        %{value: 0.0, label: :incorrect}
    end
  end

  defp default_instructions(partial_credit) do
    partial_letter = if partial_credit, do: "P", else: ""
    partial_prompt = if partial_credit, do: "\"P\" for partially correct answers,", else: ""

    """
    After assessing the submitted answer, reply with 'GRADE: $LETTER' (without quotes) where LETTER is one of C#{partial_letter}I. Please choose ONE option for the grade: either "C" for correct answers, #{partial_prompt}or "I" for incorrect answers.

    For example, after reviewing a correct answer you might write 'GRADE: C' or after reviewing an incorrect answer you might write 'GRADE: I'.

    First, write out in a step by step manner your reasoning about the criterion to be sure that your conclusion is correct. Avoid simply stating the correct answers at the outset. Then, end with your answer formatted as 'GRADE: $LETTER' (without quotes) where LETTER is one of C#{partial_letter}I.
    """
  end

  defp build_generate_opts(opts) do
    opts =
      opts
      |> Keyword.drop([
        :generate_fn,
        :template,
        :prompt,
        :instructions,
        :grade_pattern,
        :partial_credit
      ])

    model = Keyword.get(opts, :model)
    model_role = Keyword.get(opts, :model_role, "grader")

    cond do
      model != nil ->
        Keyword.put(opts, :model, model)

      model_role != nil ->
        Keyword.put_new(opts, :model_role, model_role)

      true ->
        opts
    end
  end
end
