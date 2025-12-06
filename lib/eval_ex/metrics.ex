defmodule EvalEx.Metrics do
  @moduledoc """
  Built-in evaluation metrics.

  Provides common metrics for model evaluation including exact match, F1,
  BLEU, ROUGE, and domain-specific metrics like entailment and citation accuracy.
  """

  @doc """
  Exact string match between prediction and ground truth.

  Returns 1.0 for exact match, 0.0 otherwise.
  """
  def exact_match(prediction, ground_truth) do
    if normalize_string(prediction) == normalize_string(ground_truth) do
      1.0
    else
      0.0
    end
  end

  @doc """
  Token-level F1 score.

  Computes precision and recall based on overlapping tokens.
  """
  def f1(prediction, ground_truth) do
    pred_tokens = tokenize(prediction)
    truth_tokens = tokenize(ground_truth)

    if Enum.empty?(pred_tokens) and Enum.empty?(truth_tokens) do
      1.0
    else
      common = MapSet.intersection(MapSet.new(pred_tokens), MapSet.new(truth_tokens))
      common_count = MapSet.size(common)

      if common_count == 0 do
        0.0
      else
        precision = common_count / length(pred_tokens)
        recall = common_count / length(truth_tokens)
        2 * (precision * recall) / (precision + recall)
      end
    end
  end

  @doc """
  BLEU score using simple n-gram overlap.

  This is a simplified version for basic evaluation.
  For production use, consider a full BLEU implementation.
  """
  def bleu(prediction, ground_truth, max_n \\ 4) do
    pred_tokens = tokenize(prediction)
    truth_tokens = tokenize(ground_truth)

    # Adjust n to not exceed token count
    n = min(max_n, min(length(pred_tokens), length(truth_tokens)))

    if n == 0 do
      if length(pred_tokens) == 0 and length(truth_tokens) == 0 do
        1.0
      else
        0.0
      end
    else
      scores =
        for i <- 1..n do
          pred_ngrams = ngrams(pred_tokens, i)
          truth_ngrams = ngrams(truth_tokens, i)

          common = MapSet.intersection(MapSet.new(pred_ngrams), MapSet.new(truth_ngrams))
          common_count = MapSet.size(common)

          if length(pred_ngrams) == 0 do
            0.0
          else
            common_count / length(pred_ngrams)
          end
        end

      # Geometric mean
      if Enum.all?(scores, &(&1 > 0)) do
        scores
        |> Enum.reduce(1.0, &(&1 * &2))
        |> :math.pow(1 / n)
      else
        0.0
      end
    end
  end

  @doc """
  ROUGE-L score (longest common subsequence).

  Measures the longest common subsequence between prediction and ground truth.
  """
  def rouge(prediction, ground_truth) do
    pred_tokens = tokenize(prediction)
    truth_tokens = tokenize(ground_truth)

    lcs_length = lcs(pred_tokens, truth_tokens)

    if length(pred_tokens) == 0 and length(truth_tokens) == 0 do
      1.0
    else
      precision = if length(pred_tokens) > 0, do: lcs_length / length(pred_tokens), else: 0.0
      recall = if length(truth_tokens) > 0, do: lcs_length / length(truth_tokens), else: 0.0

      if precision + recall > 0 do
        2 * (precision * recall) / (precision + recall)
      else
        0.0
      end
    end
  end

  @doc """
  Entailment score placeholder.

  In production, this would call a DeBERTa-v3 NLI model.
  For now, returns a simple token overlap score.
  """
  def entailment(prediction, ground_truth) do
    # TODO: Integrate with actual NLI model (DeBERTa-v3)
    # For now, use token overlap as proxy
    f1(prediction, ground_truth)
  end

  @doc """
  Citation accuracy placeholder.

  In production, this would validate that citations exist and support claims.
  For now, returns 1.0 if prediction contains citation markers.
  """
  def citation_accuracy(prediction, _ground_truth) when is_binary(prediction) do
    # Simple heuristic: check for citation patterns like [c1], CLAIM[c1], etc.
    if Regex.match?(~r/\[c\d+\]|CLAIM\[c\d+\]/i, prediction) do
      1.0
    else
      0.0
    end
  end

  def citation_accuracy(prediction, ground_truth) when is_map(prediction) do
    # For structured predictions, check citation fields
    citations = Map.get(prediction, :citations, Map.get(prediction, "citations", []))

    if is_list(citations) and length(citations) > 0 do
      # Validate citations exist in ground truth evidence
      truth_evidence = Map.get(ground_truth, :evidence, Map.get(ground_truth, "evidence", []))
      validate_citations(citations, truth_evidence)
    else
      0.0
    end
  end

  def citation_accuracy(_prediction, _ground_truth), do: 0.0

  @doc """
  Schema compliance checker.

  Validates that prediction conforms to expected schema.
  """
  def schema_compliance(prediction, schema) when is_map(prediction) and is_map(schema) do
    required_keys = Map.get(schema, :required, [])

    missing_keys =
      Enum.filter(required_keys, fn key ->
        not Map.has_key?(prediction, key) and not Map.has_key?(prediction, to_string(key))
      end)

    if Enum.empty?(missing_keys) do
      1.0
    else
      max(0.0, 1.0 - length(missing_keys) / length(required_keys))
    end
  end

  def schema_compliance(_prediction, _schema), do: 0.0

  # Private helpers

  defp normalize_string(str) when is_binary(str) do
    str
    |> String.downcase()
    |> String.trim()
  end

  defp normalize_string(other), do: to_string(other)

  defp tokenize(text) when is_binary(text) do
    text
    |> String.downcase()
    |> String.split(~r/\W+/, trim: true)
  end

  defp tokenize(_), do: []

  defp ngrams(tokens, n) when length(tokens) >= n do
    tokens
    |> Enum.chunk_every(n, 1, :discard)
    |> Enum.map(&Enum.join(&1, " "))
  end

  defp ngrams(_, _), do: []

  defp lcs([], _), do: 0
  defp lcs(_, []), do: 0

  defp lcs([h | t1], [h | t2]) do
    1 + lcs(t1, t2)
  end

  defp lcs([h1 | t1] = l1, [h2 | t2] = l2) when h1 != h2 do
    max(lcs(l1, t2), lcs(t1, l2))
  end

  defp validate_citations(citations, evidence) do
    valid_count =
      Enum.count(citations, fn citation ->
        citation_id = extract_citation_id(citation)
        Enum.any?(evidence, fn ev -> matches_citation?(ev, citation_id) end)
      end)

    if length(citations) > 0 do
      valid_count / length(citations)
    else
      0.0
    end
  end

  defp extract_citation_id(citation) when is_binary(citation) do
    case Regex.run(~r/\[?([ec]\d+)\]?/i, citation) do
      [_, id] -> String.downcase(id)
      _ -> citation
    end
  end

  defp extract_citation_id(citation), do: to_string(citation)

  defp matches_citation?(evidence, citation_id) when is_map(evidence) do
    evidence_id =
      Map.get(evidence, :id, Map.get(evidence, "id", ""))
      |> to_string()
      |> String.downcase()

    evidence_id == citation_id or String.contains?(evidence_id, citation_id)
  end

  defp matches_citation?(_, _), do: false
end
