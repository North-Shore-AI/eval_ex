defmodule EvalEx.SuitesTest do
  use ExUnit.Case, async: true

  alias EvalEx.Suites

  describe "Suites module" do
    test "provides access to CNS Proposer suite" do
      assert Suites.cns_proposer() == EvalEx.Suites.CNSProposer
    end

    test "provides access to CNS Antagonist suite" do
      assert Suites.cns_antagonist() == EvalEx.Suites.CNSAntagonist
    end

    test "provides access to CNS Full suite" do
      assert Suites.cns_full() == EvalEx.Suites.CNSFull
    end

    test "lists all available suites" do
      suites = Suites.all()

      assert length(suites) == 3
      assert {:cns_proposer, EvalEx.Suites.CNSProposer} in suites
      assert {:cns_antagonist, EvalEx.Suites.CNSAntagonist} in suites
      assert {:cns_full, EvalEx.Suites.CNSFull} in suites
    end

    test "gets suite by name" do
      assert {:ok, EvalEx.Suites.CNSProposer} = Suites.get(:cns_proposer)
      assert {:ok, EvalEx.Suites.CNSAntagonist} = Suites.get(:cns_antagonist)
      assert {:ok, EvalEx.Suites.CNSFull} = Suites.get(:cns_full)
    end

    test "returns error for unknown suite" do
      assert {:error, :unknown_suite} = Suites.get(:unknown)
    end
  end

  describe "CNSProposer suite" do
    test "has correct configuration" do
      suite = Suites.cns_proposer()

      assert suite.name() == "cns_proposer"
      assert suite.dataset() == :scifact
      assert :schema_compliance in suite.metrics()
      assert :citation_accuracy in suite.metrics()
      assert :entailment in suite.metrics()
      assert :similarity in suite.metrics()
    end

    test "evaluates structured predictions" do
      suite = Suites.cns_proposer()

      prediction = %{
        hypothesis: "Vitamin D reduces COVID severity",
        claims: [
          %{id: "c1", text: "Vitamin D deficiency correlates with severe outcomes"}
        ],
        evidence: [
          %{id: "e1", text: "Study shows correlation", citations: ["[e1]"]}
        ]
      }

      ground_truth = %{
        hypothesis: "Vitamin D supplementation reduces COVID-19 severity",
        evidence: [%{id: "e1", text: "Study shows correlation"}]
      }

      result = suite.evaluate(prediction, ground_truth)

      assert is_map(result)
      assert Map.has_key?(result, :schema_compliance)
      assert Map.has_key?(result, :citation_accuracy)
      assert Map.has_key?(result, :entailment)
      assert Map.has_key?(result, :similarity)
    end
  end

  describe "CNSAntagonist suite" do
    test "has correct configuration" do
      suite = Suites.cns_antagonist()

      assert suite.name() == "cns_antagonist"
      assert suite.dataset() == :synthetic_contradictions
      assert :precision in suite.metrics()
      assert :recall in suite.metrics()
      assert :f1 in suite.metrics()
      assert :beta1_accuracy in suite.metrics()
      assert :flag_actionability in suite.metrics()
    end

    test "evaluates contradiction detection" do
      suite = Suites.cns_antagonist()

      prediction = %{
        flags: [
          %{id: "f1", type: "contradiction", severity: "HIGH"},
          %{id: "f2", type: "unsupported", severity: "MEDIUM"}
        ],
        beta1: 0.45
      }

      ground_truth = %{
        contradictions: [
          %{id: "f1", type: "contradiction"}
        ],
        beta1: 0.50,
        actionable: [
          %{id: "f1"}
        ]
      }

      result = suite.evaluate(prediction, ground_truth)

      assert is_map(result)
      assert result.precision == 0.5
      assert result.recall == 1.0
      assert result.beta1_accuracy > 0.0
    end
  end

  describe "CNSFull suite" do
    test "has correct configuration" do
      suite = Suites.cns_full()

      assert suite.name() == "cns_full_pipeline"
      assert suite.dataset() == :scifact
      assert :schema_compliance in suite.metrics()
      assert :citation_accuracy in suite.metrics()
      assert :beta1_reduction in suite.metrics()
      assert :critic_pass_rate in suite.metrics()
      assert :iterations in suite.metrics()
    end

    test "evaluates full pipeline output" do
      suite = Suites.cns_full()

      prediction = %{
        hypothesis: "Synthesized hypothesis",
        claims: [%{id: "c1", text: "Claim"}],
        evidence: [%{id: "e1", text: "Evidence"}],
        initial_beta1: 0.6,
        beta1: 0.3,
        grounding_score: 0.85,
        critics: %{
          grounding: %{score: 0.8},
          logic: %{score: 0.75},
          novelty: %{score: 0.65}
        },
        iterations: 3
      }

      ground_truth = %{
        evidence: [%{id: "e1", text: "Evidence"}]
      }

      result = suite.evaluate(prediction, ground_truth)

      assert is_map(result)
      assert result.schema_compliance == 1.0
      assert result.beta1_reduction == 1.0
      assert result.critic_pass_rate > 0.0
      assert result.iterations > 0.0
    end
  end
end
