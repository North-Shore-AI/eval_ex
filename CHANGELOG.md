# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.5] - 2025-12-28

### Changed

- Bump `crucible_datasets` dependency to `~> 0.5.4`

## [0.1.4] - 2025-12-25

### Fixed

- Fix compile warning for undefined `EvalEx.Datasets.load/1` by using `apply/3` for runtime dispatch
- Credo fixes for code quality

### Changed

- Bump `crucible_datasets` dependency to `~> 0.5.3`

## [0.1.3] - 2025-12-25

### Changed

- Bump `crucible_datasets` dependency to `~> 0.5.2`

## [0.1.2] - 2025-12-24

### Added

- `task/2` macro and task definitions metadata for registry discovery
- Dataset adapter for CrucibleDatasets -> EvalEx samples
- LLMJudge `GRADE: C/I/P` parsing with partial credit and grader model role
- Accuracy and stderr metric helpers for scorer aggregation

### Changed

- Task struct expanded with inspect-ai limits/config metadata
- Sample struct expanded with sandbox/files/setup fields
- README/docs updated for new task/decorator and grading semantics

## [0.1.1] - 2025-12-23

### Added

- **inspect-ai Parity Modules**: Added core evaluation abstractions inspired by inspect-ai
  - `EvalEx.Task` - Evaluation task definition with behaviour support
  - `EvalEx.Task.Registry` - GenServer-based task discovery registry
  - `EvalEx.Sample` - Rich sample struct with metadata, scores, and error tracking
  - `EvalEx.Scorer` - Behaviour for implementing custom scorers
  - `EvalEx.Scorer.ExactMatch` - Exact string match scorer with normalization
  - `EvalEx.Scorer.LLMJudge` - LLM-as-judge scorer with dependency injection
  - `EvalEx.Error` - Error categorization for evaluation failures

### Technical Details

- All scorers are pure functions - LLMJudge takes a `generate_fn` as dependency
- Task Registry enables task discovery similar to inspect-ai's `@task` decorator
- Comprehensive test coverage for all new modules (152 tests, 0 failures)
- Zero compilation warnings

## [0.1.0] - Initial Release

### Added

- Core evaluation framework with `EvalEx.Evaluation` behaviour
- Built-in metrics: exact match, F1, BLEU, ROUGE, METEOR, entailment
- CNS benchmark suites for Proposer, Antagonist, and full pipeline
- Statistical comparison tools with confidence intervals and effect sizes
- Crucible integration for experiment tracking
- Parallel execution support
