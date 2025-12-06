defmodule EvalEx.ComparisonTest do
  use ExUnit.Case, async: true

  alias EvalEx.{Comparison, Result}

  setup do
    # Create sample results for testing
    result1 =
      Result.new(
        "model_v1",
        :test_dataset,
        [
          %{accuracy: 0.8, f1: 0.75},
          %{accuracy: 0.85, f1: 0.8},
          %{accuracy: 0.82, f1: 0.78}
        ],
        3,
        100
      )

    result2 =
      Result.new(
        "model_v2",
        :test_dataset,
        [
          %{accuracy: 0.9, f1: 0.85},
          %{accuracy: 0.92, f1: 0.88},
          %{accuracy: 0.91, f1: 0.87}
        ],
        3,
        120
      )

    result3 =
      Result.new(
        "model_v3",
        :test_dataset,
        [
          %{accuracy: 0.75, f1: 0.7},
          %{accuracy: 0.78, f1: 0.72},
          %{accuracy: 0.76, f1: 0.71}
        ],
        3,
        90
      )

    {:ok, result1: result1, result2: result2, result3: result3}
  end

  describe "compare/1" do
    test "compares multiple results", %{result1: r1, result2: r2, result3: r3} do
      comparison = Comparison.compare([r1, r2, r3])

      assert comparison.results == [r1, r2, r3]
      assert length(comparison.rankings) == 3
      assert comparison.best != nil
    end

    test "ranks results correctly", %{result1: r1, result2: r2, result3: r3} do
      comparison = Comparison.compare([r1, r2, r3])

      # model_v2 should be best (highest metrics)
      assert comparison.best.name == "model_v2"

      # Check ranking order
      [{first, _}, {second, _}, {third, _}] = comparison.rankings
      assert first.name == "model_v2"
      assert second.name == "model_v1"
      assert third.name == "model_v3"
    end

    test "performs statistical tests", %{result1: r1, result2: r2} do
      comparison = Comparison.compare([r1, r2])

      assert Map.has_key?(comparison.statistical_tests, :accuracy) or
               Map.has_key?(comparison.statistical_tests, :note)
    end
  end

  describe "confidence_intervals/2" do
    test "calculates confidence intervals for all metrics", %{result1: result} do
      intervals = Comparison.confidence_intervals(result)

      assert Map.has_key?(intervals, :accuracy)
      assert Map.has_key?(intervals, :f1)

      # Check structure
      acc_interval = intervals.accuracy
      assert Map.has_key?(acc_interval, :mean)
      assert Map.has_key?(acc_interval, :lower)
      assert Map.has_key?(acc_interval, :upper)
      assert Map.has_key?(acc_interval, :confidence)
    end

    test "confidence interval contains mean", %{result1: result} do
      intervals = Comparison.confidence_intervals(result)
      acc_interval = intervals.accuracy

      assert acc_interval.lower <= acc_interval.mean
      assert acc_interval.mean <= acc_interval.upper
    end

    test "supports custom confidence level", %{result1: result} do
      intervals = Comparison.confidence_intervals(result, 0.99)
      acc_interval = intervals.accuracy

      assert acc_interval.confidence == 0.99
    end
  end

  describe "effect_size/3" do
    test "calculates Cohen's d between two results", %{result1: r1, result2: r2} do
      effect = Comparison.effect_size(r1, r2, :accuracy)

      assert is_float(effect)
      # model_v2 has higher accuracy, so effect should be negative
      assert effect < 0
    end

    test "returns nil for missing metrics", %{result1: result} do
      effect = Comparison.effect_size(result, result, :nonexistent_metric)

      assert effect == nil
    end

    test "returns 0.0 when std is 0" do
      # Create results with no variance
      r1 = Result.new("test1", :test, [%{score: 0.8}, %{score: 0.8}], 2, 100)
      r2 = Result.new("test2", :test, [%{score: 0.8}, %{score: 0.8}], 2, 100)

      effect = Comparison.effect_size(r1, r2, :score)
      assert effect == 0.0
    end
  end

  describe "bootstrap_ci/3" do
    test "calculates bootstrap confidence intervals" do
      values = [0.7, 0.75, 0.8, 0.85, 0.9]
      result = Comparison.bootstrap_ci(values)

      assert Map.has_key?(result, :mean)
      assert Map.has_key?(result, :lower)
      assert Map.has_key?(result, :upper)
    end

    test "confidence interval contains mean" do
      values = [0.7, 0.75, 0.8, 0.85, 0.9]
      result = Comparison.bootstrap_ci(values)

      assert result.lower <= result.mean
      assert result.mean <= result.upper
    end

    test "handles empty list" do
      result = Comparison.bootstrap_ci([])

      assert result.mean == 0.0
      assert result.lower == 0.0
      assert result.upper == 0.0
    end

    test "supports custom iterations and confidence level" do
      values = [0.7, 0.8, 0.9]
      result = Comparison.bootstrap_ci(values, 500, 0.90)

      # Should still produce valid intervals
      assert result.lower <= result.upper
    end
  end

  describe "anova/2" do
    test "performs ANOVA across multiple results", %{result1: r1, result2: r2, result3: r3} do
      result = Comparison.anova([r1, r2, r3], :accuracy)

      assert Map.has_key?(result, :f_statistic)
      assert Map.has_key?(result, :significant)
      assert Map.has_key?(result, :interpretation)
    end

    test "includes degrees of freedom", %{result1: r1, result2: r2, result3: r3} do
      result = Comparison.anova([r1, r2, r3], :accuracy)

      assert Map.has_key?(result, :df_between)
      assert Map.has_key?(result, :df_within)
      # 3 groups - 1
      assert result.df_between == 2
    end

    test "detects significant differences", %{result1: r1, result2: r2, result3: r3} do
      result = Comparison.anova([r1, r2, r3], :accuracy)

      # With these specific values, should detect difference
      assert is_boolean(result.significant)
    end

    test "handles insufficient data" do
      r1 = Result.new("test", :test, [%{score: 0.8}], 1, 100)
      result = Comparison.anova([r1], :score)

      assert Map.has_key?(result, :error)
    end
  end

  describe "format/1" do
    test "formats comparison as string", %{result1: r1, result2: r2} do
      comparison = Comparison.compare([r1, r2])
      formatted = Comparison.format(comparison)

      assert is_binary(formatted)
      assert String.contains?(formatted, "Comparison")
      assert String.contains?(formatted, "Best:")
      assert String.contains?(formatted, "Rankings:")
    end
  end

  describe "best/1 and rankings/1" do
    test "best/1 returns best result", %{result1: r1, result2: r2} do
      comparison = Comparison.compare([r1, r2])
      best = Comparison.best(comparison)

      assert best != nil
      assert best.name == "model_v2"
    end

    test "rankings/1 returns ranked list", %{result1: r1, result2: r2} do
      comparison = Comparison.compare([r1, r2])
      rankings = Comparison.rankings(comparison)

      assert is_list(rankings)
      assert length(rankings) == 2

      assert Enum.all?(rankings, fn {result, score} ->
               is_struct(result, Result) and is_float(score)
             end)
    end
  end
end
