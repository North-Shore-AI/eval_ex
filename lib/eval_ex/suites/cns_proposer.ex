defmodule EvalEx.Suites.CNSProposer do
  @moduledoc """
  Standard evaluation suite for CNS Proposer agent.

  Evaluates claim extraction, evidence grounding, and schema compliance
  according to CNS 3.0 specifications.

  ## Metrics

    - Schema compliance: 100% target (hard requirement)
    - Citation accuracy: 96%+ target (hard gate)
    - Entailment score: 0.75+ target
    - Semantic similarity: 0.70+ target

  """

  use EvalEx.Evaluation

  @impl true
  def name, do: "cns_proposer"

  @impl true
  def dataset, do: :scifact

  @impl true
  def metrics, do: [:schema_compliance, :citation_accuracy, :entailment, :similarity]

  @impl true
  def evaluate(prediction, ground_truth) do
    %{
      schema_compliance: evaluate_schema(prediction),
      citation_accuracy: evaluate_citations(prediction, ground_truth),
      entailment: evaluate_entailment(prediction, ground_truth),
      similarity: evaluate_similarity(prediction, ground_truth)
    }
  end

  @impl true
  def preprocess(prediction) when is_binary(prediction) do
    # Parse structured output if string
    case Jason.decode(prediction) do
      {:ok, parsed} -> parsed
      _ -> %{text: prediction}
    end
  end

  def preprocess(prediction), do: prediction

  # Private evaluation functions

  defp evaluate_schema(prediction) do
    schema = %{
      required: [:hypothesis, :claims, :evidence]
    }

    EvalEx.Metrics.schema_compliance(prediction, schema)
  end

  defp evaluate_citations(prediction, ground_truth) do
    EvalEx.Metrics.citation_accuracy(prediction, ground_truth)
  end

  defp evaluate_entailment(prediction, ground_truth) do
    pred_text = extract_text(prediction)
    truth_text = extract_text(ground_truth)
    EvalEx.Metrics.entailment(pred_text, truth_text)
  end

  defp evaluate_similarity(prediction, ground_truth) do
    pred_text = extract_text(prediction)
    truth_text = extract_text(ground_truth)
    EvalEx.Metrics.f1(pred_text, truth_text)
  end

  defp extract_text(data) when is_map(data) do
    cond do
      Map.has_key?(data, :hypothesis) -> Map.get(data, :hypothesis)
      Map.has_key?(data, "hypothesis") -> Map.get(data, "hypothesis")
      Map.has_key?(data, :text) -> Map.get(data, :text)
      Map.has_key?(data, "text") -> Map.get(data, "text")
      true -> Jason.encode!(data)
    end
  end

  defp extract_text(data) when is_binary(data), do: data
  defp extract_text(data), do: to_string(data)
end
