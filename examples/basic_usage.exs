# Basic usage example for EvalEx
# Run with: mix run examples/basic_usage.exs

# Define a custom evaluation
defmodule MyProposerEval do
  use EvalEx.Evaluation

  @impl true
  def name, do: "my_proposer_eval"

  @impl true
  def dataset, do: :scifact

  @impl true
  def metrics, do: [:entailment, :citation_accuracy, :schema_compliance]

  @impl true
  def evaluate(prediction, ground_truth) do
    %{
      entailment: EvalEx.Metrics.entailment(prediction, ground_truth),
      citation_accuracy: EvalEx.Metrics.citation_accuracy(prediction, ground_truth),
      schema_compliance: EvalEx.Metrics.schema_compliance(prediction, %{required: [:hypothesis]})
    }
  end
end

# Example predictions and ground truth
predictions = [
  %{
    hypothesis: "Vitamin D reduces COVID-19 severity",
    claims: [%{id: "c1", text: "Study shows correlation"}],
    evidence: [%{id: "e1", text: "Research indicates benefit"}],
    citations: ["e1"]
  },
  %{
    hypothesis: "Exercise improves cardiovascular health",
    claims: [%{id: "c1", text: "Regular exercise strengthens heart"}],
    evidence: [%{id: "e1", text: "Clinical trials demonstrate improvement"}],
    citations: ["e1"]
  },
  %{
    hypothesis: "Sleep deprivation impairs cognitive function",
    claims: [%{id: "c1", text: "Lack of sleep affects memory"}],
    evidence: [%{id: "e1", text: "Studies show memory decline"}],
    citations: ["e1"]
  }
]

ground_truth = [
  %{
    hypothesis: "Vitamin D supplementation reduces COVID-19 severity",
    evidence: [%{id: "e1", text: "Research indicates benefit"}]
  },
  %{
    hypothesis: "Regular exercise improves cardiovascular health",
    evidence: [%{id: "e1", text: "Clinical trials demonstrate improvement"}]
  },
  %{
    hypothesis: "Sleep deprivation significantly impairs cognitive function",
    evidence: [%{id: "e1", text: "Studies show memory decline"}]
  }
]

IO.puts("Running evaluation...")
{:ok, result} = EvalEx.run(MyProposerEval, predictions, ground_truth: ground_truth)

IO.puts("\n" <> EvalEx.Result.format(result))

# Use pre-configured CNS Proposer suite
IO.puts("\n=== Using CNS Proposer Suite ===")

{:ok, cns_result} =
  EvalEx.run(EvalEx.Suites.cns_proposer(), predictions, ground_truth: ground_truth)

IO.puts(EvalEx.Result.format(cns_result))

# Compare multiple runs
IO.puts("\n=== Comparison ===")
comparison = EvalEx.compare([result, cns_result])
IO.puts(EvalEx.Comparison.format(comparison))
