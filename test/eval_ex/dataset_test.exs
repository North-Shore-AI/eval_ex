defmodule EvalEx.DatasetTest do
  use ExUnit.Case, async: true

  alias CrucibleDatasets.Dataset, as: CDataset
  alias EvalEx.{Dataset, Sample}

  describe "to_samples/1" do
    test "converts CrucibleDatasets.Dataset items" do
      dataset =
        CDataset.new(
          "test",
          "1.0",
          [%{id: "1", input: "Q1", expected: "A1"}],
          %{}
        )

      [sample] = Dataset.to_samples(dataset)

      assert %Sample{} = sample
      assert sample.id == "1"
      assert sample.input == "Q1"
      assert sample.target == "A1"
    end

    test "maps question/choices input into sample fields" do
      dataset =
        CDataset.new(
          "test",
          "1.0",
          [%{id: "1", input: %{question: "Q", choices: ["A", "B"]}, expected: "A"}],
          %{}
        )

      [sample] = Dataset.to_samples(dataset)

      assert sample.input == "Q"
      assert sample.choices == ["A", "B"]
    end

    test "accepts lists of samples and maps" do
      samples = [
        Sample.new(id: "s1", input: "Q", target: "A"),
        %{id: "s2", input: "Q2", target: "A2"}
      ]

      [sample1, sample2] = Dataset.to_samples(samples)

      assert sample1.id == "s1"
      assert sample2.id == "s2"
    end
  end
end
