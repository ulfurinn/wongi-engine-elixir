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

  @type rule() :: Rule.t()
  @type rule_option :: {:forall, list(matcher())} | {:do, list(action())}
  @type matcher() :: Wongi.Engine.DSL.Clause.t()
  @type action() :: any()

  defmacro __using__(_) do
    quote do
      import Wongi.Engine.DSL
      import Wongi.Engine.Aggregates
    end
  end

  @spec rule(atom(), list(rule_option())) :: rule()
  def rule(name \\ nil, opts) do
    Rule.new(
      name,
      Keyword.get(opts, :forall, []),
      Keyword.get(opts, :do, [])
    )
  end

  @doc """
  A matcher that passes if the specified fact is present in the working memory.

  `:_` can be used as a wildcard that matches any value.

  Variables can be declared using `var/1`. The first time a template that
  contains a variable is matched, the variable is bound to the value of the
  corresponding field in the fact. Subsequent matches will only succeed if the
  value of the field is equal to the bound value.
  """
  @spec has(any(), any(), any(), list(Has.option())) :: matcher()
  def has(s, p, o, opts \\ []), do: Has.new(s, p, o, opts)
  @doc "Synonym for `has/3`, `has/4`."
  @spec fact(any(), any(), any(), list(Has.option())) :: matcher()
  def fact(s, p, o, opts \\ []), do: Has.new(s, p, o, opts)

  @doc """
  A matcher that passes if the specified fact is not present in the working
  memory.

  Variables declared inside the neg matcher do not become bound, since the
  execution will only continue if there were no matching facts; however, if the
  same variable is used in multiple positions within the same neg template,
  unification will be done on it in the scope of the matcher.
  """
  @spec neg(any(), any(), any()) :: matcher()
  def neg(s, p, o), do: Neg.new(s, p, o)
  @doc "Synonym for `neg/3`."
  @spec missing(any(), any(), any()) :: matcher()
  def missing(s, p, o), do: Neg.new(s, p, o)

  @doc "A matcher that passes if the entire sub-chain does not pass."
  @spec ncc(list(matcher())) :: matcher()
  def ncc(subchain), do: NCC.new(subchain)
  @doc "Synonym for `ncc/1`."
  @spec none(list(matcher())) :: matcher()
  def none(subchain), do: NCC.new(subchain)

  @doc """
  A matcher that always passes but declares a new variable in the token.

  The value can be constant or a function with arities 0, 1, or 2. A unary
  function receives the token as its argument. A binary function receives the
  token and the entire engine as its arguments.
  """
  def assign(name, value), do: Assign.new(name, value)

  @doc "A filter that passes if the values are equal."
  def equal(a, b), do: Filter.new(Equal.new(a, b))

  @doc "A filter that passes if the values are not equal."
  def diff(a, b), do: Filter.new(Diff.new(a, b))

  @doc "A filter that passes if the first value is less than the second."
  def less(a, b), do: Filter.new(Less.new(a, b))

  @doc "A filter that passes if the first value is less than or equal to the second."
  def lte(a, b), do: Filter.new(LTE.new(a, b))

  @doc "A filter that passes if the first value is greater than the second."
  def greater(a, b), do: Filter.new(Greater.new(a, b))

  @doc "A filter that passes if the first value is greater than or equal to the second."
  def gte(a, b), do: Filter.new(GTE.new(a, b))

  @doc """
  A filter that passes if the first value is a member of the second, which is an
  enumerable.

  The name is misleading since the second value can be anything that implements
  `Enumerable`, but it is kept for similarity with the Ruby DSL.
  """
  def in_list(a, b), do: Filter.new(InList.new(a, b))

  @doc """
  A filter that passes if the first value is not a member of the second, which
  is an enumerable.

  The name is misleading since the second value can be anything that implements
  `Enumerable`, but it is kept for similarity with the Ruby DSL.
  """
  def not_in_list(a, b), do: Filter.new(NotInList.new(a, b))

  @doc """
  A filter that passes if the value is a function that returns true.

  The function can have arities 0 or 1. A unary function receives the token as
  its argument.
  """
  def filter(func), do: Filter.new(Function.new(func))

  @doc """
  A filter that passes if the value is a unary function that returns true.

  The function will receive the variable value as its argument.
  """
  def filter(var, func), do: Filter.new(Function.new(var, func))

  @doc """
  A matcher that computes some value across all its incoming tokens, across all
  execution paths.

  The matcher produces exactly one token per partition group, unless the
  partition group contains no tokens, in which case the matcher does not pass
  for that group.
  """
  def aggregate(fun, var, opts), do: Aggregate.new(fun, var, opts)

  @doc "Variable declaration."
  @spec var(atom()) :: Var.t()
  def var(name), do: Var.new(name)

  @doc "Placeholder variable. Synonym for `:_`."
  def any, do: :_

  @doc "A matcher that passes if any of the sub-chains passes."
  @spec any(list(list(matcher))) :: matcher()
  def any(clauses), do: Any.new(clauses)

  @doc """
  An action that produces new facts.

  Variables can be used to refer to values in the token.
  """
  @spec gen(any(), any(), any()) :: action()
  def gen(s, p, o), do: Generator.new(s, p, o)

  defprotocol Clause do
    @moduledoc "Rule matcher."
    def compile(clause, context)
  end
end
