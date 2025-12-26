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
  @spec exact_match(String.t() | term(), String.t() | term()) :: float()
  def exact_match(prediction, ground_truth) do
    if normalize_string(prediction) == normalize_string(ground_truth) do
      1.0
    else
      0.0
    end
  end

  @doc """
  Mean accuracy for a list of numeric scores.
  """
  @spec accuracy([number()]) :: float()
  def accuracy(values) when is_list(values) do
    case values do
      [] -> 0.0
      _ -> Enum.sum(values) / length(values)
    end
  end

  @doc """
  Standard error of the mean for a list of numeric scores.
  """
  @spec stderr([number()]) :: float()
  def stderr(values) when is_list(values) do
    n = length(values)

    if n < 2 do
      0.0
    else
      mean = Enum.sum(values) / n

      variance =
        values
        |> Enum.reduce(0.0, fn value, acc -> acc + :math.pow(value - mean, 2) end)
        |> Kernel./(n - 1)

      std = :math.sqrt(variance)
      std / :math.sqrt(n)
    end
  end

  @doc """
  Token-level F1 score.

  Computes precision and recall based on overlapping tokens.
  """
  @spec f1(String.t() | term(), String.t() | term()) :: float()
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
  @spec bleu(String.t() | term(), String.t() | term(), pos_integer()) :: float()
  def bleu(prediction, ground_truth, max_n \\ 4) do
    pred_tokens = tokenize(prediction)
    truth_tokens = tokenize(ground_truth)

    # Adjust n to not exceed token count
    n = min(max_n, min(length(pred_tokens), length(truth_tokens)))

    if n == 0 do
      if Enum.empty?(pred_tokens) and Enum.empty?(truth_tokens) do
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

          if Enum.empty?(pred_ngrams) do
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
  @spec rouge(String.t() | term(), String.t() | term()) :: float()
  def rouge(prediction, ground_truth) do
    pred_tokens = tokenize(prediction)
    truth_tokens = tokenize(ground_truth)

    lcs_length = lcs(pred_tokens, truth_tokens)

    pred_len = length(pred_tokens)
    truth_len = length(truth_tokens)

    if pred_len == 0 and truth_len == 0 do
      1.0
    else
      precision = if pred_len > 0, do: lcs_length / pred_len, else: 0.0
      recall = if truth_len > 0, do: lcs_length / truth_len, else: 0.0

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
  @spec entailment(term(), term()) :: float()
  def entailment(prediction, ground_truth) do
    # NOTE: Placeholder - production would integrate with NLI model (DeBERTa-v3)
    # For now, use token overlap as proxy
    f1(prediction, ground_truth)
  end

  @doc """
  Citation accuracy placeholder.

  In production, this would validate that citations exist and support claims.
  For now, returns 1.0 if prediction contains citation markers.
  """
  @spec citation_accuracy(term(), term()) :: float()
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

    if is_list(citations) and not Enum.empty?(citations) do
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
  @spec schema_compliance(term(), term()) :: float()
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

  @doc """
  Fuzzy string match using Levenshtein distance.

  Returns similarity score between 0.0 and 1.0 based on edit distance.
  """
  @spec fuzzy_match(String.t() | term(), String.t() | term()) :: float()
  def fuzzy_match(prediction, ground_truth)
      when is_binary(prediction) and is_binary(ground_truth) do
    pred = normalize_string(prediction)
    truth = normalize_string(ground_truth)

    distance = levenshtein_distance(pred, truth)
    max_len = max(String.length(pred), String.length(truth))

    if max_len == 0 do
      1.0
    else
      1.0 - distance / max_len
    end
  end

  def fuzzy_match(prediction, ground_truth) do
    fuzzy_match(to_string(prediction), to_string(ground_truth))
  end

  @doc """
  METEOR score approximation.

  Measures alignment considering synonyms, stemming, and paraphrasing.
  This is a simplified version focusing on unigram matching and word order.
  """
  @spec meteor(String.t() | term(), String.t() | term()) :: float()
  def meteor(prediction, ground_truth) do
    pred_tokens = tokenize(prediction)
    truth_tokens = tokenize(ground_truth)

    if Enum.empty?(pred_tokens) and Enum.empty?(truth_tokens) do
      1.0
    else
      # Calculate unigram matches
      matches = count_matches(pred_tokens, truth_tokens)

      # Calculate precision and recall
      pred_len = length(pred_tokens)
      truth_len = length(truth_tokens)
      precision = if pred_len > 0, do: matches / pred_len, else: 0.0
      recall = if truth_len > 0, do: matches / truth_len, else: 0.0

      # Calculate F-mean with higher weight on recall
      if precision + recall > 0 do
        f_mean = 10 * precision * recall / (9 * precision + recall)
        # Apply penalty for fragmentation (simplified - no chunk calculation)
        penalty = 0.5 * :math.pow(matches / (matches + 1), 3)
        f_mean * (1 - penalty)
      else
        0.0
      end
    end
  end

  @doc """
  Pass@k metric for code generation.

  Measures the percentage of test cases passed for k code samples.
  Expects prediction and ground_truth to contain execution results.
  """
  @spec pass_at_k(map() | list(), map() | list(), pos_integer()) :: float()
  def pass_at_k(predictions, _ground_truth, k \\ 1)

  def pass_at_k(predictions, _ground_truth, k) when is_list(predictions) do
    # Predictions should be a list of execution results
    # Each result should have :passed field
    passed_count =
      predictions
      |> Enum.take(k)
      |> Enum.count(fn pred -> Map.get(pred, :passed, false) end)

    passed_count / k
  end

  def pass_at_k(prediction, _ground_truth, _k) when is_map(prediction) do
    # Single prediction case
    if Map.get(prediction, :passed, false), do: 1.0, else: 0.0
  end

  def pass_at_k(_prediction, _ground_truth, _k), do: 0.0

  @doc """
  BERTScore placeholder.

  In production, this would use a transformer model to compute semantic similarity.
  For now, returns a simple embedding-based similarity proxy.
  """
  @spec bert_score(term(), term()) :: map()
  def bert_score(prediction, ground_truth) do
    # NOTE: Placeholder - production would integrate with BERT/transformer model
    # For now, return token-based similarity as placeholder
    similarity = f1(prediction, ground_truth)

    %{
      precision: similarity,
      recall: similarity,
      f1: similarity
    }
  end

  @doc """
  Perplexity metric for language model outputs.

  Measures how well a probability model predicts a sample.
  Lower perplexity indicates better predictions.
  """
  @spec perplexity(list(float())) :: float()
  def perplexity(log_probs) when is_list(log_probs) do
    if Enum.empty?(log_probs) do
      0.0
    else
      # Calculate average negative log likelihood
      avg_nll = -Enum.sum(log_probs) / length(log_probs)
      # Return perplexity as exp(avg_nll)
      :math.exp(avg_nll)
    end
  end

  def perplexity(_), do: 0.0

  @doc """
  Diversity metrics for text generation.

  Measures the diversity of generated text using distinct n-grams.
  Returns a map with distinct-1, distinct-2, and distinct-3 ratios.
  """
  @spec diversity(String.t() | term()) :: map()
  def diversity(text) when is_binary(text) do
    tokens = tokenize(text)
    total = length(tokens)

    if total == 0 do
      %{distinct_1: 0.0, distinct_2: 0.0, distinct_3: 0.0}
    else
      %{
        distinct_1: distinct_n_ratio(tokens, 1),
        distinct_2: distinct_n_ratio(tokens, 2),
        distinct_3: distinct_n_ratio(tokens, 3)
      }
    end
  end

  def diversity(text), do: diversity(to_string(text))

  @doc """
  Factual consistency check.

  Validates that facts in prediction are consistent with ground truth.
  This is a simplified version - production would use NLI models.
  """
  @spec factual_consistency(term(), term()) :: float()
  def factual_consistency(prediction, ground_truth) do
    # Simple heuristic: check if key entities from ground truth appear in prediction
    pred_str = to_string(prediction) |> String.downcase()
    truth_str = to_string(ground_truth) |> String.downcase()

    # Extract potential entities (words with capital letters or numbers)
    truth_tokens = tokenize(truth_str)

    if Enum.empty?(truth_tokens) do
      1.0
    else
      matched =
        Enum.count(truth_tokens, fn token ->
          String.contains?(pred_str, token)
        end)

      matched / length(truth_tokens)
    end
  end

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

    if Enum.empty?(citations) do
      0.0
    else
      valid_count / length(citations)
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

  # Levenshtein distance calculation
  defp levenshtein_distance("", str), do: String.length(str)
  defp levenshtein_distance(str, ""), do: String.length(str)

  defp levenshtein_distance(str1, str2) do
    {dist, _cache} =
      do_levenshtein(
        String.graphemes(str1),
        String.graphemes(str2),
        String.length(str1),
        String.length(str2),
        %{}
      )

    dist
  end

  defp do_levenshtein(_, _, 0, j, cache), do: {j, cache}
  defp do_levenshtein(_, _, i, 0, cache), do: {i, cache}

  defp do_levenshtein(s1, s2, i, j, cache) do
    key = {i, j}

    case Map.get(cache, key) do
      nil ->
        {dist, new_cache} =
          if Enum.at(s1, i - 1) == Enum.at(s2, j - 1) do
            do_levenshtein(s1, s2, i - 1, j - 1, cache)
          else
            {d1, c1} = do_levenshtein(s1, s2, i - 1, j, cache)
            {d2, c2} = do_levenshtein(s1, s2, i, j - 1, c1)
            {d3, c3} = do_levenshtein(s1, s2, i - 1, j - 1, c2)
            {1 + min(d1, min(d2, d3)), c3}
          end

        {dist, Map.put(new_cache, key, dist)}

      cached_dist ->
        {cached_dist, cache}
    end
  end

  # Count matching tokens
  defp count_matches(tokens1, tokens2) do
    set1 = MapSet.new(tokens1)
    set2 = MapSet.new(tokens2)
    MapSet.intersection(set1, set2) |> MapSet.size()
  end

  # Calculate distinct n-gram ratio
  defp distinct_n_ratio(tokens, n) do
    ngrams_list = ngrams(tokens, n)
    total = length(ngrams_list)

    if total == 0 do
      0.0
    else
      unique = ngrams_list |> MapSet.new() |> MapSet.size()
      unique / total
    end
  end
end
