defmodule EvalEx.Suites do
  @moduledoc """
  Pre-defined benchmark suites for common evaluation tasks.

  Provides convenient access to standard evaluation suites including
  CNS agent evaluations.
  """

  alias EvalEx.Suites.{CNSProposer, CNSAntagonist, CNSFull}

  @doc """
  Returns the CNS Proposer evaluation suite.

  Evaluates claim extraction, evidence grounding, and schema compliance.
  """
  def cns_proposer, do: CNSProposer

  @doc """
  Returns the CNS Antagonist evaluation suite.

  Evaluates contradiction detection, precision, recall, and beta-1 quantification.
  """
  def cns_antagonist, do: CNSAntagonist

  @doc """
  Returns the full CNS pipeline evaluation suite.

  Evaluates end-to-end Proposer -> Antagonist -> Synthesizer pipeline.
  """
  def cns_full, do: CNSFull

  @doc """
  Lists all available suites.
  """
  def all do
    [
      {:cns_proposer, CNSProposer},
      {:cns_antagonist, CNSAntagonist},
      {:cns_full, CNSFull}
    ]
  end

  @doc """
  Gets a suite by name.
  """
  def get(name) do
    case name do
      :cns_proposer -> {:ok, CNSProposer}
      :cns_antagonist -> {:ok, CNSAntagonist}
      :cns_full -> {:ok, CNSFull}
      _ -> {:error, :unknown_suite}
    end
  end
end
