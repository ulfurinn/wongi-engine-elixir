defmodule Wongi.Engine.Aggregates do
  @moduledoc "Aggregate helpers."
  def min(enum) do
    Enum.min(enum, &<=/2, fn -> nil end)
  end

  def max(enum) do
    Enum.max(enum, &>=/2, fn -> nil end)
  end

  def sum(enum) do
    Enum.reduce(enum, 0, &+/2)
  end

  def product(enum) do
    Enum.reduce(enum, 1, &*/2)
  end
end
