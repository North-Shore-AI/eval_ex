defmodule EvalEx.Scorer do
  @moduledoc """
  Behaviour for scoring model outputs.

  Scorers are pure functions - they don't call LLMs directly.
  LLMJudge takes a generate_fn as dependency, allowing the
  actual LLM backend to be injected by the caller.

  ## Usage

  Implement a custom scorer:

      defmodule MyScorer do
        use EvalEx.Scorer

        @impl true
        def score(sample, _opts) do
          value = calculate_score(sample.model_output, sample.target)
          {:ok, %{
            value: value,
            answer: sample.model_output,
            explanation: "Calculated score",
            metadata: %{}
          }}
        end
      end

  Use the scorer:

      sample = EvalEx.Sample.new(input: "test", target: "expected")
      |> EvalEx.Sample.with_output("actual")

      {:ok, score} = MyScorer.score(sample, [])
  """

  @type score :: %{
          value: float() | String.t(),
          answer: String.t() | nil,
          explanation: String.t() | nil,
          metadata: map()
        }

  @callback score(sample :: EvalEx.Sample.t(), opts :: keyword()) ::
              {:ok, score()} | {:error, term()}

  @callback scorer_id() :: String.t()
  @callback metrics() :: [atom()]

  @optional_callbacks metrics: 0

  @doc """
  Use this module to implement a scorer.

  Automatically generates a `scorer_id/0` function based on the module name,
  which can be overridden if needed.
  """
  defmacro __using__(_opts) do
    quote do
      @behaviour EvalEx.Scorer

      @doc """
      Returns the unique identifier for this scorer.

      By default, generates an ID from the module name (e.g., ExactMatch -> "exact_match").
      Can be overridden in the implementing module.
      """
      def scorer_id, do: __MODULE__ |> Module.split() |> List.last() |> Macro.underscore()

      @doc """
      Metrics exposed by this scorer (defaults to []).
      """
      def metrics, do: []

      defoverridable scorer_id: 0, metrics: 0
    end
  end
end
