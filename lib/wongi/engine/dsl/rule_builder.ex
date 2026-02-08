defmodule Wongi.Engine.DSL.RuleBuilder do
  @moduledoc """
  Composable rule builder using state-threading pattern.

  This module provides the core building blocks for constructing Wongi rules
  in a composable way. It threads a `%Rule{}` struct through a series of
  operations, each of which can add clauses and produce values for subsequent
  operations.

  Used internally by `RuleBuilder.Compose` and `RuleBuilder.Syntax`.

  ## How it works

  A `%RuleBuilder{}` wraps a function `Rule -> {result, Rule}`. When composed
  with `bind/2`, each step receives the result from the previous step and
  can modify the Rule state. Finally, `run/2` executes the chain with an
  initial Rule and returns the completed Rule struct.

  ## Example

      iex> alias Wongi.Engine.DSL.RuleBuilder
      iex> builder =
      ...>   RuleBuilder.pure(:a)
      ...>   |> RuleBuilder.bind(fn :a -> RuleBuilder.pure(:b) end)
      ...>   |> RuleBuilder.bind(fn :b -> RuleBuilder.pure(:done) end)
      iex> rule = RuleBuilder.run(builder, :my_rule)
      iex> rule.name
      :my_rule
  """

  alias Wongi.Engine.DSL.Rule

  defstruct [:run]

  @type t :: %__MODULE__{run: (Rule.t() -> {any(), Rule.t()})}

  @doc """
  Wraps a value in a RuleBuilder without modifying the Rule state.

  This is useful for returning a final value or for lifting a plain value
  into the RuleBuilder context.

  ## Examples

      iex> builder = RuleBuilder.pure(:ok)
      iex> rule = RuleBuilder.run(builder, :test)
      iex> rule.forall
      []
  """
  @spec pure(any()) :: t()
  def pure(value) do
    %__MODULE__{run: fn rule -> {value, rule} end}
  end

  @doc """
  Chains two RuleBuilder operations together.

  Runs the first builder, passes its result to the continuation function,
  then runs the resulting builder with the updated Rule state.

  This is the core composition mechanism - it threads both the Rule state
  and the result values through the computation.

  ## Examples

      iex> builder =
      ...>   RuleBuilder.pure(1)
      ...>   |> RuleBuilder.bind(fn x -> RuleBuilder.pure(x + 1) end)
      ...>   |> RuleBuilder.bind(fn x -> RuleBuilder.pure(x * 2) end)
      iex> # Result would be (1 + 1) * 2 = 4
  """
  @spec bind(t(), (any() -> t())) :: t()
  def bind(%__MODULE__{run: run_a}, cont_fn) when is_function(cont_fn, 1) do
    %__MODULE__{
      run: fn rule ->
        {result, rule1} = run_a.(rule)

        case cont_fn.(result) do
          %__MODULE__{run: run_b} ->
            run_b.(rule1)

          other ->
            raise ArgumentError,
                  "bind continuation must return a RuleBuilder, got: #{inspect(other)}"
        end
      end
    }
  end

  @doc """
  Executes a RuleBuilder chain and produces a finalized Rule struct.

  Creates an initial Rule with the given name, runs all the composed
  operations, then reverses the forall and actions lists (since operations
  prepend to these lists for efficiency).

  ## Examples

      iex> rule = RuleBuilder.pure(:ok) |> RuleBuilder.run(:my_rule)
      iex> rule.name
      :my_rule
      iex> is_reference(rule.ref)
      true
  """
  @spec run(t(), atom()) :: Rule.t()
  def run(%__MODULE__{run: run_fn}, name) do
    initial = %Rule{
      ref: make_ref(),
      name: name,
      forall: [],
      actions: [],
      mode: :full,
      bound_vars: MapSet.new()
    }

    {_final_value, rule} = run_fn.(initial)
    %{rule | forall: Enum.reverse(rule.forall), actions: Enum.reverse(rule.actions)}
  end

  @doc """
  Runs a RuleBuilder in matcher-only mode to extract clauses.

  This is used by `any()` and `ncc()` to process their inner RuleBuilders.
  Actions are not allowed in this mode and will raise an error.

  Returns `{clauses, bound_vars}` where:
  - `clauses` - list of forall clauses (in order)
  - `bound_vars` - MapSet of variable names that were bound

  ## Examples

      iex> builder = Compose.has(var(:x), :foo, var(:y))
      iex> {clauses, vars} = RuleBuilder.run_matcher_only(builder)
      iex> length(clauses)
      1
      iex> MapSet.member?(vars, :x)
      true
  """
  @spec run_matcher_only(t()) :: {list(), MapSet.t(atom())}
  def run_matcher_only(%__MODULE__{run: run_fn}) do
    initial = %Rule{
      ref: nil,
      name: nil,
      forall: [],
      actions: [],
      mode: :matcher_only,
      bound_vars: MapSet.new()
    }

    {_final_value, rule} = run_fn.(initial)
    {Enum.reverse(rule.forall), rule.bound_vars}
  end
end
