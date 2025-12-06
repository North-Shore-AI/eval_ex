defmodule EvalEx.Suites.CNSFull do
  @moduledoc """
  Full CNS pipeline evaluation suite.

  Evaluates the complete Proposer -> Antagonist -> Synthesizer pipeline
  with end-to-end metrics.

  ## Metrics

    - Schema compliance: Proposer output validation
    - Citation accuracy: Evidence grounding
    - Beta-1 reduction: Synthesis quality (target: 30%+ reduction)
    - Critic pass rate: All critics passing thresholds
    - Convergence: Iterations to completion

  """

  use EvalEx.Evaluation

  @impl true
  def name, do: "cns_full_pipeline"

  @impl true
  def dataset, do: :scifact

  @impl true
  def metrics,
    do: [:schema_compliance, :citation_accuracy, :beta1_reduction, :critic_pass_rate, :iterations]

  @impl true
  def evaluate(prediction, ground_truth) do
    %{
      schema_compliance: evaluate_schema(prediction),
      citation_accuracy: evaluate_citations(prediction, ground_truth),
      beta1_reduction: evaluate_beta1_reduction(prediction),
      critic_pass_rate: evaluate_critic_pass_rate(prediction),
      iterations: evaluate_iterations(prediction)
    }
  end

  @impl true
  def preprocess(prediction) when is_binary(prediction) do
    case Jason.decode(prediction) do
      {:ok, parsed} -> parsed
      _ -> %{}
    end
  end

  def preprocess(prediction), do: prediction

  # Private evaluation functions

  defp evaluate_schema(prediction) do
    schema = %{
      required: [:hypothesis, :claims, :evidence, :beta1, :grounding_score]
    }

    EvalEx.Metrics.schema_compliance(prediction, schema)
  end

  defp evaluate_citations(prediction, ground_truth) do
    EvalEx.Metrics.citation_accuracy(prediction, ground_truth)
  end

  defp evaluate_beta1_reduction(prediction) when is_map(prediction) do
    initial_beta1 = Map.get(prediction, :initial_beta1, Map.get(prediction, "initial_beta1", 0.0))
    final_beta1 = Map.get(prediction, :beta1, Map.get(prediction, "beta1", 0.0))

    if initial_beta1 > 0 do
      reduction = (initial_beta1 - final_beta1) / initial_beta1
      # Target is 30%+ reduction, so score is 1.0 at 30% or higher
      min(reduction / 0.3, 1.0)
    else
      if final_beta1 == 0.0, do: 1.0, else: 0.0
    end
  end

  defp evaluate_beta1_reduction(_), do: 0.0

  defp evaluate_critic_pass_rate(prediction) when is_map(prediction) do
    critics = Map.get(prediction, :critics, Map.get(prediction, "critics", %{}))

    if map_size(critics) > 0 do
      passing =
        Enum.count(critics, fn {name, result} ->
          score = get_critic_score(result)
          score >= get_critic_threshold(name)
        end)

      passing / map_size(critics)
    else
      0.0
    end
  end

  defp evaluate_critic_pass_rate(_), do: 0.0

  defp evaluate_iterations(prediction) when is_map(prediction) do
    iterations = Map.get(prediction, :iterations, Map.get(prediction, "iterations", 0))

    # Lower is better; normalize to 0-1 where 1 iteration = 1.0, 10+ iterations = 0.0
    max(0.0, 1.0 - (iterations - 1) / 9)
  end

  defp evaluate_iterations(_), do: 0.0

  # Helper functions

  defp get_critic_score(result) when is_map(result) do
    Map.get(result, :score, Map.get(result, "score", 0.0))
  end

  defp get_critic_score(result) when is_number(result), do: result
  defp get_critic_score(_), do: 0.0

  defp get_critic_threshold(critic_name) do
    # CNS 3.0 thresholds from playbook
    case to_string(critic_name) do
      "grounding" -> 0.75
      "logic" -> 0.70
      "novelty" -> 0.60
      "bias" -> 0.80
      _ -> 0.70
    end
  end
end
