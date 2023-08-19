defmodule Wongi.Engine.Aggregates do
  @moduledoc "Aggregate helpers."
  defdelegate min(enum), to: Enum

  defdelegate max(enum), to: Enum

  def sum(enum) do
    Enum.reduce(enum, 0, &+/2)
  end

  def product(enum) do
    Enum.reduce(enum, 1, &*/2)
  end
end
