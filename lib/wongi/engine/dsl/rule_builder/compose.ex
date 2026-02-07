defmodule Wongi.Engine.DSL.RuleBuilder.Compose do
  @moduledoc """
  Composable DSL functions for building Wongi rules.

  Each function returns a `%RuleBuilder{}` that adds a clause to the rule
  and yields a value for use in subsequent operations.

  ## Phase Ordering

  Rules must have forall clauses before action clauses. This module enforces
  this by raising `ArgumentError` if you try to add a forall clause (`has`,
  `neg`, `assign`, `filter`) after an action clause (`gen`).

  ## Example

      alias Wongi.Engine.DSL.RuleBuilder
      alias Wongi.Engine.DSL.RuleBuilder.Compose
      import Wongi.Engine.DSL, only: [var: 1]

      Compose.has(var(:user), :name, var(:name))
      |> RuleBuilder.bind(fn {user, _, name} ->
        Compose.has(user, :age, var(:age))
        |> RuleBuilder.bind(fn {_, _, age} ->
          Compose.gen(user, :greeted, true)
        end)
      end)
      |> RuleBuilder.run(:greet_users)

  ## With RuleBuilder.Syntax

  The `RuleBuilder.Syntax` module provides a `rule` macro that transforms
  arrow syntax into these bind chains automatically, giving a much cleaner
  syntax for rule definition.
  """

  alias Wongi.Engine.Action.Generator
  alias Wongi.Engine.DSL.Assign
  alias Wongi.Engine.DSL.Filter
  alias Wongi.Engine.DSL.Has
  alias Wongi.Engine.DSL.Neg
  alias Wongi.Engine.DSL.Rule
  alias Wongi.Engine.DSL.RuleBuilder

  @doc """
  A matcher that passes if the specified fact is present in working memory.

  Adds a `Has` clause to the rule's forall list and yields the `{s, p, o}` tuple.

  ## Parameters

  - `s` - Subject (use `var(:name)` for variables, `:_` for wildcard)
  - `p` - Predicate
  - `o` - Object
  - `opts` - Options (e.g., `when: filter_clause`)

  ## Examples

      Compose.has(var(:user), :name, var(:name))
      # Yields: {var(:user), :name, var(:name)}
  """
  @spec has(any(), any(), any(), keyword()) :: RuleBuilder.t()
  def has(s, p, o, opts \\ []) do
    forall_clause(Has.new(s, p, o, opts), {s, p, o})
  end

  @doc """
  A matcher that passes if the specified fact is NOT present in working memory.

  Adds a `Neg` clause to the rule's forall list and yields `:ok`.

  ## Variable Scoping

  Unlike `has/4`, variables inside `neg` are **locally scoped** in Wongi - new
  variables introduced in a `neg` clause are only used within the negative match
  and are NOT bound in the token for use elsewhere.

  This means:
  - **Already-bound variables** (from previous `has` clauses) work as test constraints
  - **New variables** introduced in `neg` won't be available outside

  Because of this scoping, `neg` returns `:ok` rather than a binding tuple.
  Use it as a bare expression (no `<-` arrow needed):

  ## Examples

      # GOOD: Testing with already-bound variable
      rule :check_not_deleted do
        {user, _, _} <- has(:_, :active, true)
        neg(user, :deleted, true)              # Bare call, tests bound user
        _ <- gen(user, :valid, true)
      end

      # DON'T DO: Trying to bind new variables from neg
      # {x, _, y} <- neg(:_, :foo, :_)  # x and y won't have values!
  """
  @spec neg(any(), any(), any()) :: RuleBuilder.t()
  def neg(s, p, o) do
    forall_clause(Neg.new(s, p, o), :ok)
  end

  @doc """
  Declares a new variable with a computed value.

  Adds an `Assign` clause to the rule's forall list and yields the variable
  that was assigned (typically a `Var` struct).

  The value can be:
  - A constant
  - A 0-arity function
  - A 1-arity function receiving the token
  - A 2-arity function receiving the token and engine

  ## Examples

      Compose.assign(var(:age), fn token -> calculate_age(token[:dob]) end)
      # Yields: var(:age)
  """
  @spec assign(any(), any()) :: RuleBuilder.t()
  def assign(var_to_bind, value) do
    forall_clause(Assign.new(var_to_bind, value), var_to_bind)
  end

  @doc """
  A filter that must pass for the rule to continue.

  Adds a `Filter` clause to the rule's forall list and yields `:ok`.

  The filter can be created using filter functions from `Wongi.Engine.DSL`:
  - `equal(a, b)`, `diff(a, b)`
  - `less(a, b)`, `lte(a, b)`, `greater(a, b)`, `gte(a, b)`
  - `in_list(a, b)`, `not_in_list(a, b)`
  - `filter(fn)` for custom filter functions

  ## Examples

      Compose.filter(Wongi.Engine.DSL.greater(var(:age), 18))
      # Yields: :ok
  """
  @spec filter(any()) :: RuleBuilder.t()
  def filter(filter_clause) do
    clause =
      case filter_clause do
        %Filter{} -> filter_clause
        other -> Filter.new(other)
      end

    forall_clause(clause, :ok)
  end

  @doc """
  An action that generates new facts when the rule fires.

  Adds a `Generator` action to the rule's actions list and yields `:ok`.

  Variables in the template will be resolved from the token when the rule fires.

  ## Examples

      Compose.gen(var(:user), :processed, true)
      # Yields: :ok
  """
  @spec gen(any(), any(), any()) :: RuleBuilder.t()
  def gen(s, p, o) do
    action_clause(Generator.new(s, p, o))
  end

  @doc """
  An action that generates facts using a function.

  The function receives the token and should return a WME or list of WMEs.

  ## Examples

      Compose.gen(fn token ->
        Wongi.Engine.WME.new(token[:user], :processed_at, DateTime.utc_now())
      end)
      # Yields: :ok
  """
  @spec gen((Wongi.Engine.Token.t() -> any())) :: RuleBuilder.t()
  def gen(fun) when is_function(fun, 1) do
    action_clause(Generator.new(fun))
  end

  # Private helpers

  defp forall_clause(clause, binding) do
    %RuleBuilder{
      run: fn rule ->
        check_forall_phase!(rule)
        {binding, %{rule | forall: [clause | rule.forall]}}
      end
    }
  end

  defp action_clause(action) do
    %RuleBuilder{
      run: fn %Rule{actions: actions} = rule ->
        {:ok, %{rule | actions: [action | actions]}}
      end
    }
  end

  defp check_forall_phase!(%Rule{actions: [_ | _]}) do
    raise ArgumentError,
          "cannot add forall clause after actions - forall clauses must come first"
  end

  defp check_forall_phase!(_rule), do: :ok
end
