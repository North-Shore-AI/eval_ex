# EvalEx Quick Reference

## Installation

```elixir
# mix.exs
def deps do
  [{:eval_ex, "~> 0.1.1"}]
end
```

## Define Evaluation

```elixir
defmodule MyEval do
  use EvalEx.Evaluation

  @impl true
  def name, do: "my_eval"

  @impl true
  def dataset, do: :my_dataset

  @impl true
  def metrics, do: [:accuracy, :f1]

  @impl true
  def evaluate(prediction, ground_truth) do
    %{
      accuracy: if(prediction == ground_truth, do: 1.0, else: 0.0),
      f1: EvalEx.Metrics.f1(prediction, ground_truth)
    }
  end
end
```

## Run Evaluation

```elixir
# Basic run
{:ok, result} = EvalEx.run(MyEval, predictions, ground_truth: ground_truth)

# With options
{:ok, result} = EvalEx.run(MyEval, predictions,
  ground_truth: ground_truth,
  parallel: true,
  timeout: 5000
)

# View results
IO.puts(EvalEx.Result.format(result))
```

## Use CNS Suites

```elixir
# Proposer
EvalEx.run(EvalEx.Suites.cns_proposer(), predictions, ground_truth: truth)

# Antagonist
EvalEx.run(EvalEx.Suites.cns_antagonist(), predictions, ground_truth: truth)

# Full pipeline
EvalEx.run(EvalEx.Suites.cns_full(), predictions, ground_truth: truth)
```

## Compare Results

```elixir
comparison = EvalEx.compare([result1, result2, result3])
IO.puts(EvalEx.Comparison.format(comparison))

# Get best
best_result = EvalEx.Comparison.best(comparison)

# Get rankings
rankings = EvalEx.Comparison.rankings(comparison)
```

## Metrics

```elixir
# Text metrics
EvalEx.Metrics.exact_match("hello", "hello")      # 1.0
EvalEx.Metrics.f1("the cat", "the dog")           # 0.5
EvalEx.Metrics.bleu("prediction", "reference")    # 0.0-1.0
EvalEx.Metrics.rouge("prediction", "reference")   # 0.0-1.0

# CNS metrics
EvalEx.Metrics.citation_accuracy(pred, truth)
EvalEx.Metrics.schema_compliance(pred, schema)
EvalEx.Metrics.entailment(pred, truth)
```

## Crucible Integration

```elixir
{:ok, result} = EvalEx.run_with_crucible(
  MyEval,
  predictions,
  experiment_name: "my_experiment",
  ground_truth: ground_truth,
  track_metrics: true,
  tags: ["v1", "test"],
  description: "Testing new model"
)
```

## CNS 3.0 Targets

### Proposer
- Schema compliance: ≥95%
- Citation accuracy: ≥96%
- Entailment: ≥0.75
- Similarity: ≥0.70

### Antagonist
- Precision: ≥0.8
- Recall: ≥0.7
- Beta-1 accuracy: ±10%
- Actionability: ≥80%

### Full Pipeline
- Beta-1 reduction: ≥30%
- Critic pass rate: All passing
- Iterations: <10

## Commands

```bash
# Get dependencies
mix deps.get

# Compile
mix compile

# Run tests
mix test

# Test with coverage
mix test --cover

# Run example
mix run examples/basic_usage.exs

# Generate docs
mix docs

# Format code
mix format

# Static analysis
mix credo --strict
```

## Links

- **GitHub:** https://github.com/North-Shore-AI/eval_ex
- **Docs:** `doc/index.html` (after `mix docs`)
- **Examples:** `examples/basic_usage.exs`
