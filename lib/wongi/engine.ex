defmodule Wongi.Engine do
  @moduledoc """
  A forward-chaining inference engine for Elixir.

  A port of the Ruby library with the same name.
  """

  alias Wongi.Engine.Rete

  @type t() :: Rete.t()
  @type fact() :: {any(), any(), any()} | Wongi.Engine.WME.t()
  @type template() :: {any(), any(), any()} | Wongi.Engine.WME.t()
  @type rule() :: Wongi.Engine.DSL.Rule.t()

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
  @spec select(t(), template()) :: MapSet.t()
  defdelegate select(rete, template), to: Rete

  @doc "Returns a set of all facts matching the given template."
  @spec select(t(), any(), any(), any()) :: MapSet.t()
  defdelegate select(rete, subject, predicate, object), to: Rete

  @doc "Returns a set of all tokens for the given production node reference."
  defdelegate tokens(rete, node), to: Rete
  @doc "Returns all production node references."
  defdelegate productions(rete), to: Rete
end
