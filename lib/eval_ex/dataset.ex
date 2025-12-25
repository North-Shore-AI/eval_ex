defmodule EvalEx.Dataset do
  @moduledoc """
  Dataset adapters for EvalEx.
  """

  alias CrucibleDatasets.Dataset, as: CDataset
  alias EvalEx.Sample

  @doc """
  Convert supported dataset structures into a list of EvalEx.Sample.
  """
  @spec to_samples(CDataset.t() | [Sample.t()] | [map()]) :: [Sample.t()]
  def to_samples(%CDataset{} = dataset) do
    Enum.map(dataset.items, &item_to_sample/1)
  end

  def to_samples(samples) when is_list(samples) do
    Enum.map(samples, fn
      %Sample{} = sample ->
        sample

      item when is_map(item) ->
        sample_from_map(item)
    end)
  end

  defp item_to_sample(item) do
    {input, choices} = normalize_input(Map.get(item, :input))

    Sample.new(
      id: Map.get(item, :id),
      input: input,
      target: Map.get(item, :expected, ""),
      choices: choices,
      metadata: Map.get(item, :metadata, %{})
    )
  end

  defp sample_from_map(item) do
    {input, choices} = normalize_input(Map.get(item, :input))

    Sample.new(
      id: Map.get(item, :id),
      input: input,
      target: Map.get(item, :target, Map.get(item, :expected, "")),
      choices: Map.get(item, :choices, choices),
      metadata: Map.get(item, :metadata, %{}),
      sandbox: Map.get(item, :sandbox),
      files: Map.get(item, :files),
      setup: Map.get(item, :setup)
    )
  end

  defp normalize_input(%{question: question, choices: choices})
       when is_list(choices) do
    {question, choices}
  end

  defp normalize_input(%{"question" => question, "choices" => choices})
       when is_list(choices) do
    {question, choices}
  end

  defp normalize_input(input), do: {input, nil}
end
