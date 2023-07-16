defmodule Wongi.Engine.AlphaIndex do
  @moduledoc false
  defstruct [:fields, :entries]

  def new(fields) do
    %__MODULE__{
      fields: fields,
      entries: %{}
    }
  end

  def put(%__MODULE__{fields: fields, entries: entries} = index, wme) do
    key = for field <- fields, into: [], do: wme[field]
    collection = Map.get_lazy(entries, key, &MapSet.new/0)
    entries = Map.put(entries, key, MapSet.put(collection, wme))
    %__MODULE__{index | entries: entries}
  end

  def delete(%__MODULE__{fields: fields, entries: entries} = index, wme) do
    key = for field <- fields, into: [], do: wme[field]

    case Map.fetch(entries, key) do
      {:ok, collection} ->
        entries = Map.put(entries, key, MapSet.delete(collection, wme))
        %__MODULE__{index | entries: entries}

      :error ->
        index
    end
  end

  def get(%__MODULE__{entries: entries}, key) do
    Map.get(entries, key, MapSet.new())
  end
end
