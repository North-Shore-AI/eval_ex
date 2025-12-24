# EvalEx: inspect-ai Task/Sample/Scorer Additions

**Date:** 2025-12-23
**Status:** Implementation Specification
**Purpose:** Add Task, Sample, and Scorer abstractions from inspect-ai

---

## Scope

eval_ex gets the **evaluation abstractions** from inspect-ai:

| inspect-ai | eval_ex | Purpose |
|------------|---------|---------|
| `Task` class | `EvalEx.Task` | Evaluation task definition |
| `@task` decorator | `EvalEx.Task.Registry` | Task discovery |
| `Sample` | `EvalEx.Sample` | Rich sample with metadata |
| `Scorer` protocol | `EvalEx.Scorer` | Scoring abstraction |
| `exact_match()` | `EvalEx.Scorer.ExactMatch` | Built-in scorer |
| `model_graded_qa()` | `EvalEx.Scorer.LLMJudge` | LLM-as-judge scorer |
| Error types | `EvalEx.Error` | Error categorization |

**NOT here:** Solver, Generate, TaskState (those go in crucible_harness)

**NOTE:** Scorers don't call LLMs directly. `LLMJudge` takes a generate function as a dependency - the actual LLM backend is injected by the caller.

---

## Module Specifications

### 1. EvalEx.Task

**File:** `lib/eval_ex/task.ex`

```elixir
defmodule EvalEx.Task do
  @moduledoc """
  Evaluation task definition.
  Maps to inspect-ai's Task class.
  """

  @type t :: %__MODULE__{
    id: String.t(),
    name: String.t(),
    description: String.t(),
    dataset: atom() | [EvalEx.Sample.t()],
    scorers: [module()],
    metadata: map()
  }

  defstruct [:id, :name, :description, :dataset, scorers: [], metadata: %{}]

  @callback task_id() :: String.t()
  @callback name() :: String.t()
  @callback dataset() :: atom() | [EvalEx.Sample.t()]
  @callback scorers() :: [module()]

  @optional_callbacks [description: 0, metadata: 0]

  defmacro __using__(_opts) do
    quote do
      @behaviour EvalEx.Task
      def description, do: ""
      def metadata, do: %{}
      defoverridable description: 0, metadata: 0
    end
  end

  def new(opts) do
    %__MODULE__{
      id: Keyword.fetch!(opts, :id),
      name: Keyword.fetch!(opts, :name),
      description: Keyword.get(opts, :description, ""),
      dataset: Keyword.fetch!(opts, :dataset),
      scorers: Keyword.get(opts, :scorers, []),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end
end
```

### 2. EvalEx.Task.Registry

**File:** `lib/eval_ex/task/registry.ex`

```elixir
defmodule EvalEx.Task.Registry do
  @moduledoc "Registry for discovering evaluation tasks."

  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, %{}, Keyword.put_new(opts, :name, __MODULE__))
  end

  def register(task_module), do: GenServer.call(__MODULE__, {:register, task_module})
  def get(task_id), do: GenServer.call(__MODULE__, {:get, task_id})
  def list, do: GenServer.call(__MODULE__, :list)

  @impl true
  def init(_), do: {:ok, %{}}

  @impl true
  def handle_call({:register, module}, _from, state) do
    {:reply, :ok, Map.put(state, module.task_id(), module)}
  end

  @impl true
  def handle_call({:get, id}, _from, state) do
    case Map.get(state, id) do
      nil -> {:reply, {:error, :not_found}, state}
      mod -> {:reply, {:ok, mod}, state}
    end
  end

  @impl true
  def handle_call(:list, _from, state), do: {:reply, Map.keys(state), state}
end
```

### 3. EvalEx.Sample

**File:** `lib/eval_ex/sample.ex`

```elixir
defmodule EvalEx.Sample do
  @moduledoc """
  Rich sample with per-sample metadata.
  Maps to inspect-ai's Sample class.
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

  def new(opts) do
    %__MODULE__{
      id: Keyword.get(opts, :id, generate_id()),
      input: Keyword.fetch!(opts, :input),
      target: Keyword.get(opts, :target, ""),
      choices: Keyword.get(opts, :choices),
      metadata: Keyword.get(opts, :metadata, %{})
    }
  end

  def with_output(sample, output), do: %{sample | model_output: output}
  def with_score(sample, name, score), do: %{sample | scores: Map.put(sample.scores, name, score)}
  def with_error(sample, error), do: %{sample | error: error}

  defp generate_id, do: :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
end
```

### 4. EvalEx.Scorer

**File:** `lib/eval_ex/scorer.ex`

```elixir
defmodule EvalEx.Scorer do
  @moduledoc """
  Behaviour for scoring model outputs.
  Scorers are pure functions - they don't call LLMs directly.
  LLMJudge takes a generate_fn as dependency.
  """

  @type score :: %{
    value: float() | String.t(),
    answer: String.t() | nil,
    explanation: String.t() | nil,
    metadata: map()
  }

  @callback score(sample :: EvalEx.Sample.t(), opts :: keyword()) ::
    {:ok, score()} | {:error, term()}

  @callback scorer_id() :: String.t()

  defmacro __using__(_opts) do
    quote do
      @behaviour EvalEx.Scorer
      def scorer_id, do: __MODULE__ |> Module.split() |> List.last() |> Macro.underscore()
      defoverridable scorer_id: 0
    end
  end
end
```

### 5. EvalEx.Scorer.ExactMatch

**File:** `lib/eval_ex/scorer/exact_match.ex`

```elixir
defmodule EvalEx.Scorer.ExactMatch do
  @moduledoc "Exact string match scorer."

  use EvalEx.Scorer

  @impl true
  def score(sample, _opts \\ []) do
    output = sample.model_output || ""
    targets = List.wrap(sample.target)

    matched = Enum.any?(targets, &(normalize(&1) == normalize(output)))

    {:ok, %{
      value: if(matched, do: 1.0, else: 0.0),
      answer: output,
      explanation: nil,
      metadata: %{}
    }}
  end

  defp normalize(s), do: s |> to_string() |> String.downcase() |> String.trim()
end
```

### 6. EvalEx.Scorer.LLMJudge

**File:** `lib/eval_ex/scorer/llm_judge.ex`

```elixir
defmodule EvalEx.Scorer.LLMJudge do
  @moduledoc """
  LLM-as-judge scorer. Maps to inspect-ai's model_graded_qa.

  NOTE: Does not call LLMs directly. Requires a generate_fn in opts.
  The actual LLM backend is injected by the caller.
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

    prompt = prompt_template
    |> String.replace("{input}", to_string(sample.input))
    |> String.replace("{target}", to_string(sample.target))
    |> String.replace("{response}", sample.model_output || "")

    case generate_fn.([%{role: "user", content: prompt}], opts) do
      {:ok, response} ->
        grade = parse_grade(response.content)
        {:ok, %{
          value: if(grade == :correct, do: 1.0, else: 0.0),
          answer: sample.model_output,
          explanation: response.content,
          metadata: %{grade: grade}
        }}
      error -> error
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
```

### 7. EvalEx.Error

**File:** `lib/eval_ex/error.ex`

```elixir
defmodule EvalEx.Error do
  @moduledoc "Error categorization for evaluation failures."

  @type category :: :hallucination | :factual | :formatting | :timeout | :parsing | :other

  @type t :: %__MODULE__{
    category: category(),
    message: String.t(),
    sample_id: String.t() | nil,
    details: map()
  }

  defstruct [:category, :message, :sample_id, details: %{}]

  def new(category, message, opts \\ []) do
    %__MODULE__{
      category: category,
      message: message,
      sample_id: Keyword.get(opts, :sample_id),
      details: Keyword.get(opts, :details, %{})
    }
  end

  def categorize(error) do
    cond do
      match?({:error, :timeout}, error) -> :timeout
      match?({:error, {:json, _}}, error) -> :parsing
      true -> :other
    end
  end
end
```

---

## File Structure

```
lib/eval_ex/
├── task.ex                    # NEW: Task behaviour
├── task/
│   └── registry.ex            # NEW: Task discovery
├── sample.ex                  # NEW: Rich sample struct
├── scorer.ex                  # NEW: Scorer behaviour
├── scorer/
│   ├── exact_match.ex         # NEW: String matching
│   └── llm_judge.ex           # NEW: LLM-as-judge
├── error.ex                   # NEW: Error types
└── (existing modules unchanged)
```

---

## Key Design: No Direct LLM Calls

Scorers are **pure evaluation functions**. They don't own LLM connections.

```elixir
# Caller injects the generate function
EvalEx.Scorer.LLMJudge.score(sample,
  generate_fn: &TinkexCookbook.Eval.TinkexGenerate.generate/2
)
```

This keeps eval_ex reusable without coupling to any specific LLM backend.

---

## Effort Estimate

| Component | LOC |
|-----------|-----|
| Task + Registry | 80 |
| Sample | 40 |
| Scorer behaviour | 25 |
| ExactMatch | 25 |
| LLMJudge | 45 |
| Error | 25 |
| Tests | 80 |
| **Total** | **~320** |

---

**Document Status:** Complete
**Last Updated:** 2025-12-23
