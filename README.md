<p align="center">
  <img src="assets/eval_ex.svg" alt="EvalEx" width="200">
</p>

<h1 align="center">EvalEx</h1>

<p align="center">
  <a href="https://github.com/North-Shore-AI/eval_ex/actions"><img src="https://github.com/North-Shore-AI/eval_ex/workflows/CI/badge.svg" alt="CI Status"></a>
  <a href="https://hex.pm/packages/eval_ex"><img src="https://img.shields.io/hexpm/v/eval_ex.svg" alt="Hex.pm"></a>
  <a href="https://hexdocs.pm/eval_ex"><img src="https://img.shields.io/badge/docs-hexdocs-blue.svg" alt="Documentation"></a>
  <img src="https://img.shields.io/badge/elixir-%3E%3D%201.14-purple.svg" alt="Elixir">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green.svg" alt="License"></a>
</p>

<p align="center">
  Model evaluation harness with comprehensive metrics and statistical analysis
</p>

---

EvalEx provides a framework for defining, running, and comparing model evaluations with built-in metrics, benchmark suites, and Crucible integration. Designed for the CNS 3.0 dialectical reasoning system and compatible with any ML evaluation workflow.

## Features

- **Evaluation Behaviour**: Define custom evaluations with standardized structure
- **Built-in Metrics**: Exact match, F1, BLEU, ROUGE, entailment, citation accuracy, schema compliance
- **CNS Benchmark Suites**: Pre-configured evaluations for Proposer, Antagonist, and full pipeline
- **Result Comparison**: Statistical comparison of multiple evaluation runs
- **Crucible Integration**: Submit results to Crucible Framework for tracking and visualization
- **Parallel Execution**: Run evaluations in parallel for faster results

## inspect-ai Parity

EvalEx provides evaluation abstractions inspired by [inspect-ai](https://github.com/UKGovernmentBEIS/inspect_ai):

| Module | Purpose |
|--------|---------|
| `EvalEx.Task` | Evaluation task definition with behaviour support |
| `EvalEx.Task.Registry` | GenServer-based task discovery |
| `EvalEx.Task.Definition` | Registry metadata for decorator-defined tasks |
| `EvalEx.Dataset` | Dataset adapters for CrucibleDatasets |
| `EvalEx.Sample` | Rich sample struct with metadata, scores, error tracking |
| `EvalEx.Scorer` | Behaviour for implementing custom scorers |
| `EvalEx.Scorer.ExactMatch` | Exact string match scorer with normalization |
| `EvalEx.Scorer.LLMJudge` | LLM-as-judge scorer with dependency injection |
| `EvalEx.Error` | Error categorization for evaluation failures |

### Task & Sample Usage

```elixir
# Define a task
defmodule MyTask do
  use EvalEx.Task

  @impl true
  def task_id, do: "my_task"

  @impl true
  def name, do: "My Evaluation Task"

  @impl true
  def dataset, do: :scifact

  @impl true
  def scorers, do: [EvalEx.Scorer.ExactMatch]
end

# Create samples
sample = EvalEx.Sample.new(
  id: "sample_1",
  input: "What is 2+2?",
  target: "4",
  metadata: %{difficulty: "easy"}
)
|> EvalEx.Sample.with_output("4")
|> EvalEx.Sample.with_score(:exact_match, 1.0)
```

```elixir
# Define registry-friendly tasks with the decorator macro
defmodule MyTasks do
  use EvalEx.Task, decorator: true

  task example_task(), name: "example_task" do
    EvalEx.Task.new(
      id: "example_task",
      name: "Example Task",
      dataset: []
    )
  end
end

EvalEx.Task.Registry.register_module(MyTasks)
{:ok, task} = EvalEx.Task.Registry.create("example_task")
```

```elixir
# Convert CrucibleDatasets.MemoryDataset into EvalEx samples
dataset = CrucibleDatasets.MemoryDataset.from_list([
  %{id: "1", input: "Q1", expected: "A1"}
])

samples = EvalEx.Dataset.to_samples(dataset)
```

### Scorer Usage

```elixir
# ExactMatch scorer
sample = EvalEx.Sample.new(input: "test", target: "answer")
  |> EvalEx.Sample.with_output("answer")

{:ok, score} = EvalEx.Scorer.ExactMatch.score(sample)
# => %{value: 1.0, answer: "answer", explanation: nil, metadata: %{}}

# LLMJudge scorer (requires generate_fn injection)
generate_fn = fn messages, _opts ->
  {:ok, %{content: "GRADE: C"}}
end

{:ok, score} = EvalEx.Scorer.LLMJudge.score(sample, generate_fn: generate_fn)
# => %{value: 1.0, answer: "answer", explanation: "GRADE: C", metadata: %{grade: :correct}}
```

## Installation

Add `eval_ex` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:eval_ex, "~> 0.1.5"}
  ]
end
```

## Quick Start

### Define a Custom Evaluation

```elixir
defmodule MyEval do
  use EvalEx.Evaluation

  @impl true
  def name, do: "proposer_scifact"

  @impl true
  def dataset, do: :scifact

  @impl true
  def metrics, do: [:entailment, :citation_accuracy, :schema_compliance]

  @impl true
  def evaluate(prediction, ground_truth) do
    %{
      entailment: EvalEx.Metrics.entailment(prediction, ground_truth),
      citation_accuracy: EvalEx.Metrics.citation_accuracy(prediction, ground_truth),
      schema_compliance: EvalEx.Metrics.schema_compliance(prediction, ground_truth)
    }
  end
end
```

### Run Evaluation

```elixir
# Prepare your data
predictions = [
  %{hypothesis: "Vitamin D reduces COVID severity", claims: [...], evidence: [...]},
  # ... more predictions
]

ground_truth = [
  %{hypothesis: "Ground truth hypothesis", evidence: [...]},
  # ... more ground truth
]

# Run evaluation
{:ok, result} = EvalEx.run(MyEval, predictions, ground_truth: ground_truth)

# View results
IO.puts(EvalEx.Result.format(result))
# => Evaluation: proposer_scifact
#    Dataset: scifact
#    Samples: 100
#    Duration: 1234ms
#
#    Metrics:
#      entailment: 0.7500 (±0.1200)
#      citation_accuracy: 0.9600 (±0.0500)
#      schema_compliance: 1.0000 (±0.0000)
```

### Use CNS Benchmark Suites

```elixir
# Use pre-configured CNS Proposer evaluation
{:ok, result} = EvalEx.run(
  EvalEx.Suites.cns_proposer(),
  model_outputs,
  ground_truth: scifact_data
)

# Use CNS Antagonist evaluation
{:ok, result} = EvalEx.run(
  EvalEx.Suites.cns_antagonist(),
  antagonist_outputs,
  ground_truth: synthetic_contradictions
)

# Use full pipeline evaluation
{:ok, result} = EvalEx.run(
  EvalEx.Suites.cns_full(),
  pipeline_outputs,
  ground_truth: ground_truth
)
```

### Compare Results

```elixir
# Run multiple evaluations
{:ok, result1} = EvalEx.run(MyEval, predictions_v1, ground_truth: ground_truth)
{:ok, result2} = EvalEx.run(MyEval, predictions_v2, ground_truth: ground_truth)
{:ok, result3} = EvalEx.run(MyEval, predictions_v3, ground_truth: ground_truth)

# Compare
comparison = EvalEx.compare([result1, result2, result3])

# View comparison
IO.puts(EvalEx.Comparison.format(comparison))
# => Comparison of 3 evaluations
#    Best: proposer_v2
#    Rankings:
#      1. proposer_v2: 0.8750
#      2. proposer_v3: 0.8250
#      3. proposer_v1: 0.7800
```

### Crucible Integration

```elixir
# Run with Crucible tracking
{:ok, result} = EvalEx.run_with_crucible(
  MyEval,
  predictions,
  experiment_name: "proposer_eval_v3",
  ground_truth: ground_truth,
  track_metrics: true,
  tags: ["proposer", "scifact", "v3"],
  description: "Evaluating improved claim extraction"
)

# Export for Crucible
{:ok, json} = EvalEx.Crucible.export(result, :json)
```

## Built-in Metrics

### Text Metrics

- `exact_match/2` - Exact string match (case-insensitive, trimmed)
- `fuzzy_match/2` - Fuzzy string matching using Levenshtein distance
- `f1/2` - Token-level F1 score
- `bleu/3` - BLEU score with n-gram overlap
- `rouge/2` - ROUGE-L score (longest common subsequence)
- `meteor/2` - METEOR score approximation with alignment and word order

### Semantic & Quality Metrics

- `entailment/2` - Entailment score (placeholder for NLI model integration)
- `bert_score/2` - BERTScore placeholder (returns precision, recall, f1)
- `factual_consistency/2` - Validates facts in prediction align with ground truth

### Code Generation Metrics

- `pass_at_k/3` - Pass@k metric for code generation (percentage of samples passing tests)
- `perplexity/1` - Perplexity metric for language model outputs

### Diversity & Quality Metrics

- `diversity/1` - Text diversity using distinct n-grams (distinct-1, distinct-2, distinct-3)

### CNS-Specific Metrics

- `citation_accuracy/2` - Validates citations exist and support claims
- `schema_compliance/2` - Validates prediction conforms to expected schema

### Usage

```elixir
# Simple text comparison
EvalEx.Metrics.exact_match("hello world", "Hello World")
# => 1.0

# Token overlap
EvalEx.Metrics.f1("the cat sat on the mat", "the dog sat on a mat")
# => 0.8

# Citation validation
prediction = %{
  hypothesis: "Claim text",
  citations: ["e1", "e2"]
}
ground_truth = %{
  evidence: [
    %{id: "e1", text: "Evidence 1"},
    %{id: "e2", text: "Evidence 2"}
  ]
}
EvalEx.Metrics.citation_accuracy(prediction, ground_truth)
# => 1.0

# Schema validation
prediction = %{name: "test", value: 42, status: "ok"}
schema = %{required: [:name, :value, :status]}
EvalEx.Metrics.schema_compliance(prediction, schema)
# => 1.0
```

## Statistical Analysis

EvalEx provides comprehensive statistical analysis tools for comparing evaluation results:

### Confidence Intervals

```elixir
# Calculate confidence intervals for all metrics
intervals = EvalEx.Comparison.confidence_intervals(result, 0.95)
# => %{
#      accuracy: %{mean: 0.85, lower: 0.82, upper: 0.88, confidence: 0.95},
#      f1: %{mean: 0.80, lower: 0.77, upper: 0.83, confidence: 0.95}
#    }
```

### Effect Size (Cohen's d)

```elixir
# Calculate effect size between two results
effect = EvalEx.Comparison.effect_size(result1, result2, :accuracy)
# => -0.45  (negative means result2 has higher accuracy)

# Interpretation:
# - Small: d = 0.2
# - Medium: d = 0.5
# - Large: d = 0.8
```

### Bootstrap Confidence Intervals

```elixir
# More robust than parametric methods for non-normal distributions
values = [0.7, 0.75, 0.8, 0.85, 0.9]
ci = EvalEx.Comparison.bootstrap_ci(values, 1000, 0.95)
# => %{mean: 0.80, lower: 0.71, upper: 0.89}
```

### ANOVA (Analysis of Variance)

```elixir
# Test for significant differences across multiple results
result = EvalEx.Comparison.anova([result1, result2, result3], :accuracy)
# => %{
#      f_statistic: 5.2,
#      df_between: 2,
#      df_within: 6,
#      significant: true,
#      interpretation: "Strong evidence of difference"
#    }
```

## CNS Benchmark Suites

### CNS Proposer (`EvalEx.Suites.CNSProposer`)

Evaluates claim extraction, evidence grounding, and schema compliance.

**Metrics:**
- Schema compliance: 100% target (hard requirement)
- Citation accuracy: 96%+ target (hard gate)
- Entailment score: 0.75+ target
- Semantic similarity: 0.70+ target

**Dataset:** SciFact

### CNS Antagonist (`EvalEx.Suites.CNSAntagonist`)

Evaluates contradiction detection, precision, recall, and beta-1 quantification.

**Metrics:**
- Precision: 0.8+ target (minimize false alarms)
- Recall: 0.7+ target (don't miss real contradictions)
- Beta-1 accuracy: Within ±10% of ground truth
- Flag actionability: 80%+ of HIGH flags lead to action

**Dataset:** Synthetic contradictions

### CNS Full Pipeline (`EvalEx.Suites.CNSFull`)

Evaluates end-to-end Proposer → Antagonist → Synthesizer pipeline.

**Metrics:**
- Schema compliance: Proposer output validation
- Citation accuracy: Evidence grounding
- Beta-1 reduction: Synthesis quality (target: 30%+ reduction)
- Critic pass rate: All critics passing thresholds
- Convergence: Iterations to completion

**Dataset:** SciFact

## Architecture

```
eval_ex/
├── lib/
│   └── eval_ex/
│       ├── evaluation.ex       # Evaluation behaviour
│       ├── runner.ex           # Evaluation runner
│       ├── result.ex           # Result struct
│       ├── metrics.ex          # Built-in metrics
│       ├── comparison.ex       # Result comparison
│       ├── crucible.ex         # Crucible integration
│       └── suites/
│           ├── cns_proposer.ex
│           ├── cns_antagonist.ex
│           └── cns_full.ex
└── test/
```

## CNS 3.0 Integration

EvalEx implements the evaluation framework specified in the CNS 3.0 Agent Playbook:

- **Semantic Grounding**: 4-stage validation pipeline (citation → entailment → similarity → paraphrase)
- **Agent Metrics**: Standardized success thresholds for each CNS agent
- **Statistical Testing**: T-tests for comparing evaluation runs
- **Actionable Feedback**: Detailed breakdowns for debugging and improvement

See the CNS 3.0 Agent Playbook in the tinkerer project for complete specifications.

## Development

```bash
# Get dependencies
mix deps.get

# Run tests
mix test

# Generate documentation
mix docs

# Code quality
mix format
mix credo --strict
```

## License

MIT

## Links

- [GitHub Repository](https://github.com/North-Shore-AI/eval_ex)
- [North Shore AI Monorepo](https://github.com/North-Shore-AI)
- Crucible Framework (see North Shore AI monorepo)
- CNS Project (see North Shore AI monorepo)
