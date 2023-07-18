defmodule Wongi.Engine do
  @moduledoc """
  A forward-chaining inference engine for Elixir.

  A port of the Ruby library with the same name.
  """

  alias Wongi.Engine.Rete

  defdelegate new(), to: Rete
  defdelegate compile(rete, rule), to: Rete
  defdelegate compile_and_get_ref(rete, rule), to: Rete
  defdelegate assert(rete, fact), to: Rete
  defdelegate assert(rete, subject, predicate, object), to: Rete
  defdelegate retract(rete, fact), to: Rete
  defdelegate retract(rete, subject, object, predicate), to: Rete
  defdelegate find(rete, template), to: Rete
  defdelegate find(rete, subject, predicate, object), to: Rete
  defdelegate tokens(rete, node), to: Rete
end
