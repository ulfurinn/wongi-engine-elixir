# credo:disable-for-this-file Credo.Check.Refactor.Nesting
defmodule Wongi.Engine.Token do
  @moduledoc false
  alias Wongi.Engine.Beta

  @derive {Inspect, except: [:node_ref]}
  defstruct [:node_ref, :parents, :wme, :assignments]

  def new(node, parents, wme, assignments \\ %{}) do
    %__MODULE__{
      node_ref: Beta.ref(node),
      parents: MapSet.new(parents),
      wme: wme,
      assignments: assignments
    }
  end

  def fetch(%__MODULE__{assignments: assignments, parents: parents}, var) do
    case Map.fetch(assignments, var) do
      {:ok, _value} = ok ->
        ok

      :error ->
        Enum.reduce_while(parents, :error, fn parent, :error ->
          case fetch(parent, var) do
            :error -> {:cont, :error}
            value -> {:halt, value}
          end
        end)
    end
  end

  def fetch(
        %__MODULE__{} = token,
        var,
        extra_assignments
      ) do
    case Map.fetch(extra_assignments, var) do
      {:ok, value} ->
        {:ok, value}

      :error ->
        fetch(token, var)
    end
  end

  def has_wme?(%__MODULE__{wme: wme}, wme), do: true
  def has_wme?(_, _), do: false

  def child_of?(%__MODULE__{parents: parents}, parent),
    do: MapSet.member?(parents, parent)
end