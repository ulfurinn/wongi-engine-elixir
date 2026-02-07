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
  alias Wongi.Engine.DSL.Aggregate
  alias Wongi.Engine.DSL.Any
  alias Wongi.Engine.DSL.Assign
  alias Wongi.Engine.DSL.Filter
  alias Wongi.Engine.DSL.Has
  alias Wongi.Engine.DSL.NCC
  alias Wongi.Engine.DSL.Neg
  alias Wongi.Engine.DSL.Rule
  alias Wongi.Engine.DSL.RuleBuilder
  alias Wongi.Engine.DSL.Var

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
  A matcher that computes a value across all incoming tokens per partition group.

  Adds an `Aggregate` clause to the rule's forall list and yields the output
  variable for binding.

  The aggregate produces exactly one token per partition group. If a partition
  group has no tokens, the aggregate does not pass for that group.

  ## Parameters

  - `fun` - Aggregation function (receives list of values, e.g., `&Enum.count/1`, `&Enum.min/1`)
  - `var` - Output variable (typically injected by Syntax from LHS pattern)
  - `opts` - Options:
    - `:over` - Variable to aggregate over (required)
    - `:partition` - Variable(s) to partition/group by (optional)

  ## Examples

      # With Syntax macro:
      min_weight <- aggregate(&min/1, over: weight)

      # With Compose directly:
      Compose.aggregate(&min/1, var(:min_weight), over: var(:weight))
  """
  @spec aggregate(fun(), any(), keyword()) :: RuleBuilder.t()
  def aggregate(fun, var, opts) do
    forall_clause(Aggregate.new(fun, var, opts), var)
  end

  @doc """
  A negated conjunctive condition - passes if the subchain does NOT match.

  Takes a RuleBuilder containing the subchain of clauses. The RuleBuilder is
  run in matcher-only mode (actions are not allowed) and the extracted clauses
  form the NCC subchain.

  Variables inside NCC are locally scoped - they can reference previously-bound
  variables from the outer context, but new variables introduced inside the NCC
  are not exported.

  Yields `:ok` since NCC doesn't export any variables.

  ## Examples

  With the Syntax macro:

      rule :check_valid do
        {user, _, _} <- has(:_, :active, true)

        ncc do
          {_, _, x} <- has(user, :deleted, :_)
          {_, _, _} <- has(x, :reason, :_)
        end

        _ <- gen(user, :valid, true)
      end

  With Compose directly:

      Compose.ncc(
        Compose.has(user, :deleted, var(:x))
        |> RuleBuilder.bind(fn {_, _, x} ->
          Compose.has(x, :reason, :_)
        end)
      )
  """
  @spec ncc(RuleBuilder.t()) :: RuleBuilder.t()
  def ncc(%RuleBuilder{} = builder) do
    {clauses, _bound_vars} = RuleBuilder.run_matcher_only(builder)
    forall_clause(NCC.new(clauses), :ok)
  end

  @doc """
  A disjunction - passes if any branch matches.

  Takes a list of RuleBuilders, one per branch. Each RuleBuilder is run in
  matcher-only mode (actions are not allowed) and the extracted clauses form
  the branches of the Any clause.

  Variables from inside the branches ARE exported to the outer context (unlike
  NCC). All branches should bind consistent variables.

  Yields a map of all bound variables: `%{name => var(:name)}`.

  ## Examples

  With the Syntax macro:

      rule :match_type do
        {x, _, _} <- has(:_, :entity, true)

        vars <- any do
          branch do
            {_, _, y} <- has(x, :type_a, :_)
          end
          branch do
            {_, _, y} <- has(x, :type_b, :_)
          end
        end

        # vars.y is available here
        _ <- gen(x, :matched, vars.y)
      end

  With Compose directly:

      Compose.any([
        Compose.has(x, :type_a, var(:y)),
        Compose.has(x, :type_b, var(:y))
      ])
  """
  @spec any([RuleBuilder.t()]) :: RuleBuilder.t()
  def any(branches) when is_list(branches) do
    # Process each branch to extract clauses and bound vars
    {branch_clauses, all_vars} =
      Enum.reduce(branches, {[], MapSet.new()}, fn builder, {clauses_acc, vars_acc} ->
        {clauses, bound_vars} = RuleBuilder.run_matcher_only(builder)
        {[clauses | clauses_acc], MapSet.union(vars_acc, bound_vars)}
      end)

    # Reverse to maintain order
    branch_clauses = Enum.reverse(branch_clauses)

    # Build the vars map: %{name => var(:name)}
    vars_map =
      all_vars
      |> Enum.map(fn name -> {name, %Var{name: name}} end)
      |> Map.new()

    forall_clause(Any.new(branch_clauses), vars_map)
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
        new_vars = extract_vars(binding)
        updated_vars = MapSet.union(rule.bound_vars, new_vars)
        {binding, %{rule | forall: [clause | rule.forall], bound_vars: updated_vars}}
      end
    }
  end

  defp action_clause(action) do
    %RuleBuilder{
      run: fn %Rule{actions: actions, mode: mode} = rule ->
        check_actions_allowed!(mode)
        {:ok, %{rule | actions: [action | actions]}}
      end
    }
  end

  defp check_actions_allowed!(:matcher_only) do
    raise ArgumentError,
          "actions are not allowed in matcher-only mode (inside any/ncc clauses)"
  end

  defp check_actions_allowed!(:full), do: :ok

  defp check_forall_phase!(%Rule{actions: [_ | _]}) do
    raise ArgumentError,
          "cannot add forall clause after actions - forall clauses must come first"
  end

  defp check_forall_phase!(_rule), do: :ok

  @doc """
  Extracts all Var names from a term (recursively searching tuples, lists, maps).

  Returns a MapSet of atom names.

  ## Examples

      iex> extract_vars({var(:x), :foo, var(:y)})
      MapSet.new([:x, :y])

      iex> extract_vars(:literal)
      MapSet.new()
  """
  @spec extract_vars(any()) :: MapSet.t(atom())
  def extract_vars(term) do
    do_extract_vars(term, MapSet.new())
  end

  defp do_extract_vars(%Var{name: name}, acc), do: MapSet.put(acc, name)

  defp do_extract_vars(tuple, acc) when is_tuple(tuple) do
    tuple
    |> Tuple.to_list()
    |> Enum.reduce(acc, &do_extract_vars/2)
  end

  defp do_extract_vars(list, acc) when is_list(list) do
    Enum.reduce(list, acc, &do_extract_vars/2)
  end

  defp do_extract_vars(%{} = map, acc) do
    map
    |> Map.values()
    |> Enum.reduce(acc, &do_extract_vars/2)
  end

  defp do_extract_vars(_other, acc), do: acc
end
