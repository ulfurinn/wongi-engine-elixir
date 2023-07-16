defmodule Wongi.Engine.DSL do
  @moduledoc """
  Rule definition functions.
  """
  alias Wongi.Engine.DSL.Has
  alias Wongi.Engine.DSL.Neg
  alias Wongi.Engine.DSL.Rule
  alias Wongi.Engine.DSL.Var

  def rule(name \\ nil, opts) do
    Rule.new(name, opts[:forall], opts[:do])
  end

  def has(s, p, o), do: Has.new(s, p, o)
  def fact(s, p, o), do: Has.new(s, p, o)

  def neg(s, p, o), do: Neg.new(s, p, o)
  def missing(s, p, o), do: Neg.new(s, p, o)

  def var(name), do: Var.new(name)

  def any, do: :_

  defprotocol Clause do
    def compile(clause, context)
  end
end
