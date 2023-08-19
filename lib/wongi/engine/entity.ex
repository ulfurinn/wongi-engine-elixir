defmodule Wongi.Engine.Entity do
  @moduledoc """
  An iterator-like object that represents a set of facts about a single subject.
  """
  alias Wongi.Engine.Rete
  defstruct [:rete, :subject]

  def new(rete, subject), do: %__MODULE__{rete: rete, subject: subject}

  def on(entity, rete), do: %__MODULE__{entity | rete: rete}
  def over(entity, subject), do: %__MODULE__{entity | subject: subject}

  def fetch(%__MODULE__{rete: nil}, _),
    do: raise("Entity not bound to an engine instance; use Entity.on/2")

  def fetch(%__MODULE__{subject: nil}, _),
    do: raise("Entity not bound to a subject; use Entity.over/2")

  def fetch(%__MODULE__{rete: rete, subject: subject}, predicate) do
    case Rete.select(rete, subject, predicate, :_) |> Enum.to_list() do
      [wme | _] -> {:ok, wme.object}
      [] -> :error
    end
  end

  defimpl Enumerable do
    def reduce(%@for{rete: rete, subject: subject}, acc, fun) do
      Rete.select(rete, subject, :_, :_)
      |> Enum.map(&{&1.predicate, &1.object})
      |> Enumerable.reduce(acc, fun)
    end

    def member?(%@for{rete: rete, subject: subject}, {predicate, object}) do
      {:ok, Rete.select(rete, subject, predicate, object) |> MapSet.size() > 0}
    end

    def member?(%@for{rete: rete, subject: subject}, predicate) do
      {:ok, Rete.select(rete, subject, predicate, :_) |> MapSet.size() > 0}
    end

    def count(%@for{rete: rete, subject: subject}) do
      {:ok, Rete.select(rete, subject, :_, :_) |> MapSet.size()}
    end

    def slice(_) do
      {:error, __MODULE__}
    end
  end
end
