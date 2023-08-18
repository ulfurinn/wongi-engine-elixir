defmodule Wongi.Engine.DSL do
  @moduledoc """
  Rule definition functions.
  """
  alias Wongi.Engine.Action.Generator
  alias Wongi.Engine.DSL.Aggregate
  alias Wongi.Engine.DSL.Any
  alias Wongi.Engine.DSL.Assign
  alias Wongi.Engine.DSL.Filter
  alias Wongi.Engine.DSL.Has
  alias Wongi.Engine.DSL.NCC
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

  @opaque rule() :: Rule.t()
  @type rule_option :: {:forall, list(matcher())} | {:do, list(action())}
  @type matcher() :: Wongi.Engine.DSL.Clause.t()
  @type action() :: any()

  @spec rule(atom(), list(rule_option())) :: rule()
  def rule(name \\ nil, opts) do
    Rule.new(
      name,
      Keyword.get(opts, :forall, []),
      Keyword.get(opts, :do, [])
    )
  end

  @doc "A matcher that passes if the specified fact is present in the working memory."
  @spec has(any(), any(), any(), list(Has.option())) :: matcher()
  def has(s, p, o, opts \\ []), do: Has.new(s, p, o, opts)
  @doc "Synonym for `has/3`, `has/4`."
  @spec fact(any(), any(), any(), list(Has.option())) :: matcher()
  def fact(s, p, o, opts \\ []), do: Has.new(s, p, o, opts)

  @doc "A matcher that passes if the specified fact is not present in the working memory."
  @spec neg(any(), any(), any()) :: matcher()
  def neg(s, p, o), do: Neg.new(s, p, o)
  @doc "Synonym for `neg/3`."
  @spec missing(any(), any(), any()) :: matcher()
  def missing(s, p, o), do: Neg.new(s, p, o)

  @doc "A matcher that passes if the sub-chain does not pass."
  @spec ncc(list(matcher())) :: matcher()
  def ncc(subchain), do: NCC.new(subchain)
  @doc "Synonym for `ncc/1`."
  @spec none(list(matcher())) :: matcher()
  def none(subchain), do: NCC.new(subchain)

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

  def aggregate(fun, var, opts), do: Aggregate.new(fun, var, opts)

  @doc "Variable declaration."
  @spec var(atom()) :: Var.t()
  def var(name), do: Var.new(name)

  @doc "Placeholder variable. Synonym for `:_`."
  def any, do: :_

  @doc "A matcher that passes if any of the sub-chains passes."
  @spec any(list(list(matcher))) :: matcher()
  def any(clauses), do: Any.new(clauses)

  @spec gen(any(), any(), any()) :: action()
  def gen(s, p, o), do: Generator.new(s, p, o)

  defprotocol Clause do
    @moduledoc "Rule matcher."
    def compile(clause, context)
  end
end
