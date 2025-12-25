# EvalEx: Inspect-AI Parity Requirements (2025-12-24)

Purpose: document the Task/Sample/Scorer functionality required to reproduce
inspect-ai behavior used by the Python tinker-cookbook, and map it to EvalEx.

## Python Sources (line referenced)

Inspect-AI task + dataset:
- `tinkex_cookbook/inspect_ai/src/inspect_ai/_eval/task/task.py:59-183`
  `Task` class (dataset, solver, scorer, model, config, limits).
- `tinkex_cookbook/inspect_ai/src/inspect_ai/_eval/registry.py:87-159`
  `@task` decorator and task registry.
- `tinkex_cookbook/inspect_ai/src/inspect_ai/dataset/_dataset.py:28-105`
  `Sample` class fields (input, target, choices, metadata, sandbox, files).
- `tinkex_cookbook/inspect_ai/src/inspect_ai/dataset/_dataset.py:240-320`
  `MemoryDataset` class.

Inspect-AI scorers:
- `tinkex_cookbook/inspect_ai/src/inspect_ai/scorer/_model.py:86-152`
  `model_graded_qa` LLM-as-judge scorer (grade regex, partial credit, model role).

Cookbook usage:
- `tinkex_cookbook/tinker-cookbook/tinker_cookbook/eval/custom_inspect_task.py:50-68`
  uses `@task`, `Task`, `MemoryDataset`, `Sample`, `generate()`, `model_graded_qa`.
- `tinkex_cookbook/tinker-cookbook/tinker_cookbook/recipes/chat_sl/train.py:88-108`
  inline evals reference `inspect_evals/gsm8k` and `inspect_evals/ifeval`.

## Current EvalEx Coverage (Elixir)

- `../eval_ex/lib/eval_ex/sample.ex:1-93`
  `EvalEx.Sample` (input, target, choices, metadata, model_output, scores, error).
- `../eval_ex/lib/eval_ex/task.ex:1-123`
  `EvalEx.Task` struct + behaviour for module-based tasks.
- `../eval_ex/lib/eval_ex/task/registry.ex:1-93`
  registry for task modules (manual registration).
- `../eval_ex/lib/eval_ex/scorer.ex:1-69`
  `EvalEx.Scorer` behaviour and `scorer_id`.
- `../eval_ex/lib/eval_ex/scorer/llm_judge.ex:1-84`
  minimal LLM-as-judge scorer.

Adjacent dataset support:
- `../crucible_datasets/lib/dataset_manager/memory_dataset.ex:1-105`
  `CrucibleDatasets.MemoryDataset` (inspect-ai MemoryDataset analog).

## Required Functionality for Full Parity

To run inspect-ai style tasks (including inspect_evals tasks referenced by the
cookbook), EvalEx must support:

1. Task definition + registry parity
   - Task metadata, name, version, limits, and optional solver/scorer overrides.
   - Task decorator (or equivalent) for registration and task argument metadata.

2. Dataset + Sample parity
   - Sample fields: `choices`, `metadata`, `sandbox`, `files`, `setup`.
   - MemoryDataset wrapper that can be passed into Task (or an adapter).

3. Scorer parity
   - LLM-as-judge with grade regex and partial credit.
   - Support for model roles or explicit grader model.
   - Standard metrics (accuracy, stderr) as inspect-ai defines.

## Status (v0.1.2)

- Added `task/2` macro + registry metadata for inspect-ai-style task definitions.
- Task now models limits, model/config metadata, and version/display name.
- Dataset adapter bridges CrucibleDatasets to EvalEx samples.
- LLMJudge uses `GRADE: C/I/P` parsing with partial credit and model role support.
- Scorers expose accuracy + stderr metrics.

## Remaining Gaps

- Multi-model grading aggregation is not yet implemented.

## Integration Contracts (needed outside this lib)

EvalEx is used by:
- `tinkex_cookbook` evaluation runner
  (`tinkex_cookbook/lib/tinkex_cookbook/eval/runner.ex:76-266`).
- `CrucibleHarness` solver pipeline (TaskState and Generate adapter).

These integrations need richer Task/Sample/Scorer semantics to match inspect-ai
parity, particularly for inspect_evals datasets.

## Suggested Tests (parity-focused)

- Task registration and lookup for tasks with parameters.
- Sample handling of `choices` and `metadata` with scorers.
- LLMJudge grading parity with `GRADE: C/I/P` patterns and partial credit.
