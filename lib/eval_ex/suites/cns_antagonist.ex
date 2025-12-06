defmodule EvalEx.Suites.CNSAntagonist do
  @moduledoc """
  Standard evaluation suite for CNS Antagonist agent.

  Evaluates contradiction detection, precision/recall on synthetic test suites,
  and beta-1 quantification accuracy.

  ## Metrics

    - Precision: 0.8+ target (minimize false alarms)
    - Recall: 0.7+ target (don't miss real contradictions)
    - Beta-1 accuracy: Within ±10% of ground truth
    - Flag actionability: 80%+ of HIGH flags lead to action

  """

  use EvalEx.Evaluation

  @impl true
  def name, do: "cns_antagonist"

  @impl true
  def dataset, do: :synthetic_contradictions

  @impl true
  def metrics, do: [:precision, :recall, :f1, :beta1_accuracy, :flag_actionability]

  @impl true
  def evaluate(prediction, ground_truth) do
    %{
      precision: evaluate_precision(prediction, ground_truth),
      recall: evaluate_recall(prediction, ground_truth),
      f1: evaluate_f1(prediction, ground_truth),
      beta1_accuracy: evaluate_beta1(prediction, ground_truth),
      flag_actionability: evaluate_actionability(prediction, ground_truth)
    }
  end

  @impl true
  def preprocess(prediction) when is_binary(prediction) do
    case Jason.decode(prediction) do
      {:ok, parsed} -> parsed
      _ -> %{flags: []}
    end
  end

  def preprocess(prediction), do: prediction

  # Private evaluation functions

  defp evaluate_precision(prediction, ground_truth) do
    pred_flags = extract_flags(prediction)
    true_contradictions = extract_contradictions(ground_truth)

    if Enum.empty?(pred_flags) do
      0.0
    else
      true_positives = count_true_positives(pred_flags, true_contradictions)
      true_positives / length(pred_flags)
    end
  end

  defp evaluate_recall(prediction, ground_truth) do
    pred_flags = extract_flags(prediction)
    true_contradictions = extract_contradictions(ground_truth)

    if Enum.empty?(true_contradictions) do
      1.0
    else
      true_positives = count_true_positives(pred_flags, true_contradictions)
      true_positives / length(true_contradictions)
    end
  end

  defp evaluate_f1(prediction, ground_truth) do
    precision = evaluate_precision(prediction, ground_truth)
    recall = evaluate_recall(prediction, ground_truth)

    if precision + recall > 0 do
      2 * (precision * recall) / (precision + recall)
    else
      0.0
    end
  end

  defp evaluate_beta1(prediction, ground_truth) do
    pred_beta1 = extract_beta1(prediction)
    true_beta1 = extract_beta1(ground_truth)

    if true_beta1 > 0 do
      accuracy = 1.0 - min(abs(pred_beta1 - true_beta1) / true_beta1, 1.0)
      max(accuracy, 0.0)
    else
      if pred_beta1 == 0.0, do: 1.0, else: 0.0
    end
  end

  defp evaluate_actionability(prediction, ground_truth) do
    high_severity_flags = extract_high_severity_flags(prediction)

    if Enum.empty?(high_severity_flags) do
      1.0
    else
      actionable = extract_actionable_flags(ground_truth)
      count_overlap(high_severity_flags, actionable) / length(high_severity_flags)
    end
  end

  # Helper functions

  defp extract_flags(data) when is_map(data) do
    Map.get(data, :flags, Map.get(data, "flags", []))
  end

  defp extract_flags(_), do: []

  defp extract_contradictions(data) when is_map(data) do
    Map.get(data, :contradictions, Map.get(data, "contradictions", []))
  end

  defp extract_contradictions(_), do: []

  defp count_true_positives(pred_flags, true_contradictions) do
    Enum.count(pred_flags, fn flag ->
      flag_id = extract_id(flag)
      Enum.any?(true_contradictions, fn contra -> extract_id(contra) == flag_id end)
    end)
  end

  defp extract_id(item) when is_map(item) do
    Map.get(item, :id, Map.get(item, "id", nil))
  end

  defp extract_id(_), do: nil

  defp extract_beta1(data) when is_map(data) do
    Map.get(data, :beta1, Map.get(data, "beta1", 0.0))
  end

  defp extract_beta1(_), do: 0.0

  defp extract_high_severity_flags(data) when is_map(data) do
    flags = extract_flags(data)

    Enum.filter(flags, fn flag ->
      severity = Map.get(flag, :severity, Map.get(flag, "severity", ""))
      String.upcase(to_string(severity)) == "HIGH"
    end)
  end

  defp extract_high_severity_flags(_), do: []

  defp extract_actionable_flags(data) when is_map(data) do
    Map.get(data, :actionable, Map.get(data, "actionable", []))
  end

  defp extract_actionable_flags(_), do: []

  defp count_overlap(list1, list2) do
    ids1 = Enum.map(list1, &extract_id/1) |> MapSet.new()
    ids2 = Enum.map(list2, &extract_id/1) |> MapSet.new()
    MapSet.intersection(ids1, ids2) |> MapSet.size()
  end
end
