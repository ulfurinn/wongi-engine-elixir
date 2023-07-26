defmodule Wongi.Engine.DSL do
  @moduledoc """
  Rule definition functions.
  """
  alias Wongi.Engine.Action.Generator
  alias Wongi.Engine.DSL.Any
  alias Wongi.Engine.DSL.Assign
  alias Wongi.Engine.DSL.Filter
  alias Wongi.Engine.DSL.Has
  alias Wongi.Engine.DSL.Neg
  alias Wongi.Engine.DSL.Rule
  alias Wongi.Engine.DSL.Var
  alias Wongi.Engine.Filter.Diff
  alias Wongi.Engine.Filter.Equal
  alias Wongi.Engine.Filter.Function
  alias Wongi.Engine.Filter.Greater
  alias Wongi.Engine.Filter.GTE
  alias Wongi.Engine.Filter.InList
  alias Wongi.Engine.Filter.Less
  alias Wongi.Engine.Filter.LTE
  alias Wongi.Engine.Filter.NotInList

  @spec rule(atom(), keyword) :: Rule.t()
  def rule(name \\ nil, opts) do
    Rule.new(
      name,
      Keyword.get(opts, :forall, []),
      Keyword.get(opts, :do, [])
    )
  end

  def has(s, p, o, opts \\ []), do: Has.new(s, p, o, opts)
  def fact(s, p, o, opts \\ []), do: Has.new(s, p, o, opts)

  def neg(s, p, o), do: Neg.new(s, p, o)
  def missing(s, p, o), do: Neg.new(s, p, o)

  def assign(name, value), do: Assign.new(name, value)

  def equal(a, b), do: Filter.new(Equal.new(a, b))
  def diff(a, b), do: Filter.new(Diff.new(a, b))
  def less(a, b), do: Filter.new(Less.new(a, b))
  def lte(a, b), do: Filter.new(LTE.new(a, b))
  def greater(a, b), do: Filter.new(Greater.new(a, b))
  def gte(a, b), do: Filter.new(GTE.new(a, b))
  def in_list(a, b), do: Filter.new(InList.new(a, b))
  def not_in_list(a, b), do: Filter.new(NotInList.new(a, b))
  def filter(func), do: Filter.new(Function.new(func))

  def var(name), do: Var.new(name)

  def any, do: :_
  def any(clauses), do: Any.new(clauses)

  def gen(s, p, o), do: Generator.new(s, p, o)

  defprotocol Clause do
    @moduledoc false
    def compile(clause, context)
  end
end
