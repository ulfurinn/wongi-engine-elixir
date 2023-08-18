defmodule Wongi.Engine do
  @moduledoc """
  A forward-chaining inference engine for Elixir.

  A port of the Ruby library with the same name.
  """

  alias Wongi.Engine.Entity
  alias Wongi.Engine.Rete

  @opaque t() :: Wongi.Engine.Rete.t()
  @opaque wme() :: Wongi.Engine.WME.t()
  @type fact() :: {any(), any(), any()} | wme()
  @type template() :: {any(), any(), any()} | wme()
  @opaque rule() :: Wongi.Engine.DSL.Rule.t()

  @doc """
  Creates a new engine instance.
  """
  @spec new() :: t()
  defdelegate new(), to: Rete

  @doc """
  Returns an engine with the given rule installed.

  See `Wongi.Engine.DSL` for details on the rule definition DSL.
  """
  @spec compile(t(), rule()) :: t()
  defdelegate compile(rete, rule), to: Rete

  @doc """
  Returns an engine with the given rule installed and the rule reference.

  The rule reference can be used to retrieve production tokens using `tokens/2`.

  See `Wongi.Engine.DSL` for details on the rule definition DSL.
  """
  @spec compile_and_get_ref(t(), rule()) :: {t(), reference()}
  defdelegate compile_and_get_ref(rete, rule), to: Rete

  @doc "Returns an engine with the given fact added to the working memory."
  @spec assert(t(), fact()) :: t()
  defdelegate assert(rete, fact), to: Rete

  @doc "Returns an engine with the given fact added to the working memory."
  @spec assert(t(), any(), any(), any()) :: t()
  defdelegate assert(rete, subject, predicate, object), to: Rete

  @doc "Returns an engine with the given fact removed from the working memory."
  @spec retract(t(), fact()) :: t()
  defdelegate retract(rete, fact), to: Rete

  @doc "Returns an engine with the given fact removed from the working memory."
  @spec retract(t(), any(), any(), any()) :: t()
  defdelegate retract(rete, subject, object, predicate), to: Rete

  @doc "Returns a set of all facts matching the given template."
  @spec select(t(), template()) :: MapSet.t(fact())
  defdelegate select(rete, template), to: Rete

  @doc "Returns a set of all facts matching the given template."
  @spec select(t(), any(), any(), any()) :: MapSet.t(fact())
  defdelegate select(rete, subject, predicate, object), to: Rete

  @doc "Returns a set of all tokens for the given production node reference."
  @spec tokens(t(), reference()) :: MapSet.t(Wongi.Engine.Token.t())
  defdelegate tokens(rete, node), to: Rete

  @doc "Returns all production node references."
  @spec productions(t()) :: MapSet.t(reference())
  defdelegate productions(rete), to: Rete

  def entity(rete, subject), do: Entity.new(rete, subject)
end
