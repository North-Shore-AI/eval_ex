defmodule EvalEx.ErrorTest do
  use ExUnit.Case, async: true

  alias EvalEx.Error

  describe "new/3" do
    test "creates error with required fields" do
      error = Error.new(:timeout, "Request timed out")

      assert error.category == :timeout
      assert error.message == "Request timed out"
      assert error.sample_id == nil
      assert error.details == %{}
    end

    test "creates error with optional sample_id" do
      error = Error.new(:parsing, "Invalid JSON", sample_id: "sample_123")

      assert error.category == :parsing
      assert error.message == "Invalid JSON"
      assert error.sample_id == "sample_123"
      assert error.details == %{}
    end

    test "creates error with optional details" do
      error = Error.new(:hallucination, "Ungrounded claim", details: %{claim: "xyz"})

      assert error.category == :hallucination
      assert error.message == "Ungrounded claim"
      assert error.sample_id == nil
      assert error.details == %{claim: "xyz"}
    end

    test "creates error with all fields" do
      error =
        Error.new(
          :factual,
          "Incorrect fact",
          sample_id: "s_456",
          details: %{expected: "A", got: "B"}
        )

      assert error.category == :factual
      assert error.message == "Incorrect fact"
      assert error.sample_id == "s_456"
      assert error.details == %{expected: "A", got: "B"}
    end
  end

  describe "categorize/1" do
    test "categorizes timeout errors" do
      assert Error.categorize({:error, :timeout}) == :timeout
    end

    test "categorizes JSON parsing errors" do
      assert Error.categorize({:error, {:json, "invalid"}}) == :parsing
    end

    test "categorizes other errors" do
      assert Error.categorize({:error, :unknown}) == :other
      assert Error.categorize({:error, "something else"}) == :other
    end
  end

  describe "struct fields" do
    test "supports all error categories" do
      categories = [:hallucination, :factual, :formatting, :timeout, :parsing, :other]

      for category <- categories do
        error = Error.new(category, "Test message")
        assert error.category == category
      end
    end
  end
end
