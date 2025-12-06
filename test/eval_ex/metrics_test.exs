defmodule EvalEx.MetricsTest do
  use ExUnit.Case, async: true

  alias EvalEx.Metrics

  describe "exact_match/2" do
    test "returns 1.0 for exact matches" do
      assert Metrics.exact_match("hello world", "hello world") == 1.0
    end

    test "returns 0.0 for non-matches" do
      assert Metrics.exact_match("hello", "world") == 0.0
    end

    test "is case insensitive" do
      assert Metrics.exact_match("Hello World", "hello world") == 1.0
    end

    test "trims whitespace" do
      assert Metrics.exact_match("  hello  ", "hello") == 1.0
    end
  end

  describe "f1/2" do
    test "returns 1.0 for identical texts" do
      assert Metrics.f1("the cat sat", "the cat sat") == 1.0
    end

    test "returns 0.0 for completely different texts" do
      assert Metrics.f1("cat", "dog") == 0.0
    end

    test "computes partial overlap correctly" do
      score = Metrics.f1("the cat sat on mat", "the dog sat on mat")
      assert score > 0.0
      assert score < 1.0
    end
  end

  describe "bleu/3" do
    test "returns 1.0 for identical texts" do
      assert Metrics.bleu("the cat sat", "the cat sat") == 1.0
    end

    test "returns 0.0 for no overlap" do
      assert Metrics.bleu("cat", "dog") == 0.0
    end

    test "computes n-gram overlap" do
      score = Metrics.bleu("the cat sat on the mat", "the cat sat on a mat")
      assert score > 0.0
      assert score < 1.0
    end
  end

  describe "rouge/2" do
    test "returns 1.0 for identical texts" do
      assert Metrics.rouge("the cat sat", "the cat sat") == 1.0
    end

    test "returns 0.0 for no overlap" do
      assert Metrics.rouge("cat", "dog") == 0.0
    end

    test "measures longest common subsequence" do
      score = Metrics.rouge("the big cat", "the small cat")
      assert score > 0.0
      assert score < 1.0
    end
  end

  describe "citation_accuracy/2" do
    test "returns 1.0 for text with citation markers" do
      assert Metrics.citation_accuracy("CLAIM[c1] supports this", nil) == 1.0
    end

    test "returns 0.0 for text without citations" do
      assert Metrics.citation_accuracy("No citations here", nil) == 0.0
    end

    test "validates structured citations" do
      prediction = %{
        hypothesis: "Test",
        citations: ["e1", "e2"]
      }

      ground_truth = %{
        evidence: [
          %{id: "e1", text: "Evidence 1"},
          %{id: "e2", text: "Evidence 2"}
        ]
      }

      assert Metrics.citation_accuracy(prediction, ground_truth) == 1.0
    end

    test "penalizes invalid citations" do
      prediction = %{
        hypothesis: "Test",
        citations: ["e1", "e3"]
      }

      ground_truth = %{
        evidence: [
          %{id: "e1", text: "Evidence 1"},
          %{id: "e2", text: "Evidence 2"}
        ]
      }

      score = Metrics.citation_accuracy(prediction, ground_truth)
      assert score == 0.5
    end
  end

  describe "schema_compliance/2" do
    test "returns 1.0 when all required keys present" do
      prediction = %{name: "test", value: 42, status: "ok"}
      schema = %{required: [:name, :value, :status]}

      assert Metrics.schema_compliance(prediction, schema) == 1.0
    end

    test "returns 0.0 when all required keys missing" do
      prediction = %{foo: "bar"}
      schema = %{required: [:name, :value, :status]}

      assert Metrics.schema_compliance(prediction, schema) == 0.0
    end

    test "returns partial score for partial compliance" do
      prediction = %{name: "test", value: 42}
      schema = %{required: [:name, :value, :status]}

      score = Metrics.schema_compliance(prediction, schema)
      assert score > 0.0
      assert score < 1.0
    end

    test "accepts string keys" do
      prediction = %{"name" => "test", "value" => 42}
      schema = %{required: [:name, :value]}

      assert Metrics.schema_compliance(prediction, schema) == 1.0
    end
  end
end
