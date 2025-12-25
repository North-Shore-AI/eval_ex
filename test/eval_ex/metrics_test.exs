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

  describe "fuzzy_match/2" do
    test "returns 1.0 for identical strings" do
      assert Metrics.fuzzy_match("hello", "hello") == 1.0
    end

    test "returns high similarity for minor differences" do
      score = Metrics.fuzzy_match("hello", "helo")
      assert score >= 0.8
      assert score < 1.0
    end

    test "returns low similarity for very different strings" do
      score = Metrics.fuzzy_match("hello", "world")
      assert score < 0.5
    end

    test "handles empty strings" do
      assert Metrics.fuzzy_match("", "") == 1.0
    end
  end

  describe "accuracy/1" do
    test "returns mean accuracy for numeric values" do
      assert Metrics.accuracy([1.0, 0.0, 1.0]) == 2.0 / 3.0
    end

    test "returns 0.0 for empty input" do
      assert Metrics.accuracy([]) == 0.0
    end
  end

  describe "stderr/1" do
    test "computes standard error of the mean" do
      value = Metrics.stderr([1.0, 0.0, 1.0, 0.0])
      assert_in_delta value, 0.288675, 1.0e-6
    end

    test "returns 0.0 for fewer than two samples" do
      assert Metrics.stderr([1.0]) == 0.0
      assert Metrics.stderr([]) == 0.0
    end
  end

  describe "meteor/2" do
    test "returns high score for identical texts" do
      score = Metrics.meteor("the cat sat", "the cat sat")
      # METEOR applies fragmentation penalty even for identical texts
      assert score > 0.7
    end

    test "returns 0.0 for completely different texts" do
      assert Metrics.meteor("cat", "dog") == 0.0
    end

    test "computes alignment with word order consideration" do
      score = Metrics.meteor("the cat sat on mat", "the dog sat on mat")
      assert score > 0.0
      assert score < 1.0
    end
  end

  describe "pass_at_k/3" do
    test "returns 1.0 when all samples pass" do
      predictions = [
        %{passed: true},
        %{passed: true},
        %{passed: true}
      ]

      assert Metrics.pass_at_k(predictions, nil, 3) == 1.0
    end

    test "returns 0.0 when no samples pass" do
      predictions = [
        %{passed: false},
        %{passed: false}
      ]

      assert Metrics.pass_at_k(predictions, nil, 2) == 0.0
    end

    test "computes partial pass rate" do
      predictions = [
        %{passed: true},
        %{passed: false},
        %{passed: true}
      ]

      score = Metrics.pass_at_k(predictions, nil, 3)
      assert_in_delta score, 0.667, 0.01
    end

    test "handles single prediction" do
      assert Metrics.pass_at_k(%{passed: true}, nil, 1) == 1.0
      assert Metrics.pass_at_k(%{passed: false}, nil, 1) == 0.0
    end
  end

  describe "bert_score/2" do
    test "returns map with precision, recall, f1" do
      result = Metrics.bert_score("the cat", "the cat")
      assert Map.has_key?(result, :precision)
      assert Map.has_key?(result, :recall)
      assert Map.has_key?(result, :f1)
    end

    test "returns high scores for identical texts" do
      result = Metrics.bert_score("hello world", "hello world")
      assert result.f1 == 1.0
    end
  end

  describe "perplexity/1" do
    test "computes perplexity from log probabilities" do
      log_probs = [-1.0, -1.5, -0.5]
      result = Metrics.perplexity(log_probs)
      assert result > 0.0
    end

    test "returns 0.0 for empty list" do
      assert Metrics.perplexity([]) == 0.0
    end

    test "lower perplexity for higher probabilities" do
      high_prob = [-0.1, -0.1, -0.1]
      low_prob = [-2.0, -2.0, -2.0]

      assert Metrics.perplexity(high_prob) < Metrics.perplexity(low_prob)
    end
  end

  describe "diversity/1" do
    test "returns map with distinct-1, distinct-2, distinct-3" do
      result = Metrics.diversity("the cat sat on the mat")
      assert Map.has_key?(result, :distinct_1)
      assert Map.has_key?(result, :distinct_2)
      assert Map.has_key?(result, :distinct_3)
    end

    test "high diversity for unique words" do
      result = Metrics.diversity("each word is unique here")
      assert result.distinct_1 > 0.9
    end

    test "low diversity for repeated words" do
      result = Metrics.diversity("cat cat cat cat cat")
      assert result.distinct_1 < 0.5
    end

    test "handles empty text" do
      result = Metrics.diversity("")
      assert result.distinct_1 == 0.0
    end
  end

  describe "factual_consistency/2" do
    test "returns 1.0 when all facts present" do
      prediction = "vitamin d reduces severity"
      ground_truth = "vitamin d reduces severity"
      assert Metrics.factual_consistency(prediction, ground_truth) == 1.0
    end

    test "returns partial score for partial consistency" do
      prediction = "vitamin d is important"
      ground_truth = "vitamin d reduces covid severity"
      score = Metrics.factual_consistency(prediction, ground_truth)
      assert score > 0.0
      assert score < 1.0
    end

    test "returns 0.0 for completely inconsistent facts" do
      prediction = "cats are animals"
      ground_truth = "vitamin d reduces severity"
      score = Metrics.factual_consistency(prediction, ground_truth)
      assert score == 0.0
    end
  end
end
