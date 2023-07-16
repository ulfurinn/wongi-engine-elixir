defmodule Wongi.Engine.DSL do
  @moduledoc """
  Rule definition functions.
  """
  alias Wongi.Engine.DSL.Has
  alias Wongi.Engine.DSL.Rule
  alias Wongi.Engine.DSL.Var

  def rule(name, opts) do
    Rule.new(name, opts[:forall], opts[:do])
  end

  def has(s, p, o) do
    Has.new(s, p, o)
  end

  def var(name) do
    Var.new(name)
  end

  def any do
    :_
  end

  defprotocol Clause do
    def compile(clause, context)
  end
end
