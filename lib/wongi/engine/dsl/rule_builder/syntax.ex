defmodule Wongi.Engine.DSL.RuleBuilder.Syntax do
  @moduledoc """
  Arrow syntax for building Wongi rules.

  This module provides `rule` and `defrule` macros that transform arrow (`<-`)
  syntax into RuleBuilder bind chains, giving a clean, readable syntax for rule
  definitions.

  ## Usage

      use Wongi.Engine.DSL.RuleBuilder.Syntax

      # Inline rule
      rule :calculate_age do
        {user, _, name} <- has(:_, :users_name, :_)
        {_, _, dob} <- has(user, :users_dob, :_)
        age <- assign(fn token -> calculate_age(token[dob]) end)
        _ <- gen(user, :age, age)
      end

      # Parameterized rule as a function
      defrule process_entity(entity_type, output_pred) do
        {entity, _, _} <- has(:_, :type, entity_type)
        _ <- gen(entity, output_pred, true)
      end

      # Use the parameterized rule
      engine
      |> Rete.compile(process_entity(:person, :processed))
      |> Rete.compile(process_entity(:order, :fulfilled))

  ## How It Works

  The macro transforms each `pattern <- rhs` into a `RuleBuilder.bind` call:

  1. **Variable injection**: For `has` and `neg`, variables in the LHS pattern
     are injected as `var(:name)` into RHS positions that have `:_`.

  2. **Assign handling**: For `assign`, the LHS variable becomes the first
     argument: `age <- assign(fn)` becomes `assign(var(:age), fn)`.

  3. **Bind chaining**: Each arrow becomes a nested bind, threading the rule
     state through the computation.

  ## Pattern Rules

  - `user` (bare variable) at position with `:_` → inject `var(:user)`
  - `_` (underscore) → leave as wildcard
  - `^user` (pinned) → use existing variable value (test, not bind)
  - `:literal` → leave as-is

  ## Variable Scoping

  Variables bound in patterns become real Elixir variables, giving you:
  - Full LSP support (undefined variables get flagged)
  - Meaningful names in debugging (`var(:user)` not `var(:__gs_42__)`)
  - Natural Elixir semantics for variable reuse
  """

  alias Wongi.Engine.DSL.RuleBuilder

  defmacro __using__(_opts) do
    quote do
      import Wongi.Engine.DSL.RuleBuilder.Syntax, only: [rule: 2, defrule: 2]
      import Wongi.Engine.DSL.RuleBuilder.Compose
      import Wongi.Engine.DSL, only: [var: 1]
    end
  end

  @doc """
  Define a rule using arrow syntax.

  ## Example

      rule :greet_users do
        {user, _, name} <- has(:_, :name, :_)
        _ <- gen(user, :greeted, true)
      end
  """
  defmacro rule(name, do: block) do
    build_rule(name, block)
  end

  @doc """
  Define a parameterized rule as a function.

  This macro combines function definition with rule definition, making it easy
  to create reusable, parameterized rules.

  ## Example

      defrule greet_by_type(entity_type) do
        {entity, _, _} <- has(:_, :type, entity_type)
        _ <- gen(entity, :greeted, true)
      end

      # Expands to:
      def greet_by_type(entity_type) do
        rule :greet_by_type do
          {entity, _, _} <- has(:_, :type, entity_type)
          _ <- gen(entity, :greeted, true)
        end
      end

      # Usage:
      engine
      |> Rete.compile(greet_by_type(:person))
      |> Rete.compile(greet_by_type(:robot))

  ## Notes

  - The rule name is automatically derived from the function name
  - Function arguments can be used anywhere in the rule body
  - Each call creates a new rule instance with the given parameters
  """
  defmacro defrule(call, do: block) do
    {name, args} = extract_call(call)

    quote do
      def unquote(name)(unquote_splicing(args)) do
        unquote(build_rule(name, block))
      end
    end
  end

  # Extract function name and arguments from a call AST
  defp extract_call({name, _, args}) when is_atom(name) and is_list(args) do
    {name, args}
  end

  defp extract_call({name, _, nil}) when is_atom(name) do
    {name, []}
  end

  defp extract_call(other) do
    raise ArgumentError,
          "expected a function call like `my_rule(a, b)`, got: #{Macro.to_string(other)}"
  end

  # Build the rule AST (shared by rule/2 and defrule/2)
  defp build_rule(name, block) do
    exprs = extract_exprs(block)

    # Note: caller arg is passed but not currently used
    body = build_bind_chain(exprs, nil)

    quote do
      unquote(body)
      |> RuleBuilder.run(unquote(name))
    end
  end

  # Extract expressions from block (handles single expr vs multiple)
  defp extract_exprs({:__block__, _, exprs}), do: exprs
  defp extract_exprs(expr), do: [expr]

  # Build the nested bind chain
  # Every expression in a rule block should be either:
  # - An arrow expression: `pattern <- dsl_fn(...)`
  # - A bare DSL function call: `dsl_fn(...)`
  # Both return RuleBuilder values that get chained together.

  defp build_bind_chain([], _caller) do
    # Empty rule - just return pure(:ok)
    quote do: RuleBuilder.pure(:ok)
  end

  defp build_bind_chain([{:<-, _, [pattern, rhs]}], _caller) do
    # Last expression is an arrow - transform and return directly
    transform_rhs(pattern, rhs, nil)
  end

  defp build_bind_chain([expr], caller) do
    # Last expression is bare (no arrow) - transform if needed and pass through
    # Must be a DSL function call that returns a RuleBuilder
    transform_bare_expr(expr, caller)
  end

  defp build_bind_chain([{:<-, _, [pattern, rhs]} | rest], caller) do
    transformed_rhs = transform_rhs(pattern, rhs, caller)
    rest_chain = build_bind_chain(rest, caller)

    quote do
      RuleBuilder.bind(unquote(transformed_rhs), fn unquote(pattern) ->
        unquote(rest_chain)
      end)
    end
  end

  defp build_bind_chain([expr | rest], caller) do
    # Bare expression (no arrow) followed by more expressions
    # Transform if needed, then bind with wildcard pattern since we don't need its value
    transformed_expr = transform_bare_expr(expr, caller)
    rest_chain = build_bind_chain(rest, caller)

    quote do
      RuleBuilder.bind(unquote(transformed_expr), fn _ ->
        unquote(rest_chain)
      end)
    end
  end

  # Transform bare expressions (non-arrow) that need special handling
  defp transform_bare_expr({:ncc, meta, [[do: block]]}, caller) do
    # ncc do...end as bare expression - transform the inner block
    exprs = extract_exprs(block)
    inner_builder = build_bind_chain(exprs, caller)
    {:ncc, meta, [inner_builder]}
  end

  defp transform_bare_expr(expr, _caller) do
    # Other expressions pass through unchanged
    expr
  end

  # Transform RHS based on the function being called and LHS pattern
  defp transform_rhs(pattern, {:has, meta, args}, _caller) do
    transformed_args = inject_vars_for_spo(pattern, args)
    {:has, meta, transformed_args}
  end

  defp transform_rhs(pattern, {:neg, meta, args}, _caller) do
    transformed_args = inject_vars_for_spo(pattern, args)
    {:neg, meta, transformed_args}
  end

  defp transform_rhs(pattern, {:assign, meta, [value_fn]}, _caller) do
    # For assign, inject the LHS variable name as first argument
    var_name = extract_single_var_name(pattern)

    var_ast =
      quote do
        var(unquote(var_name))
      end

    {:assign, meta, [var_ast, value_fn]}
  end

  defp transform_rhs(pattern, {:assign, meta, [var_expr, value_fn]}, _caller) do
    # assign already has var specified, but if it's :_, inject from pattern
    case var_expr do
      :_ ->
        var_name = extract_single_var_name(pattern)

        var_ast =
          quote do
            var(unquote(var_name))
          end

        {:assign, meta, [var_ast, value_fn]}

      _ ->
        {:assign, meta, [var_expr, value_fn]}
    end
  end

  defp transform_rhs(_pattern, {:filter, _meta, _args} = rhs, _caller) do
    # filter doesn't need transformation
    rhs
  end

  defp transform_rhs(pattern, {:aggregate, meta, [fun, opts]}, _caller) do
    # aggregate(fun, opts) -> aggregate(fun, var(:name), opts)
    # Inject var from LHS pattern as the output variable
    var_name = extract_single_var_name(pattern)

    var_ast =
      quote do
        var(unquote(var_name))
      end

    {:aggregate, meta, [fun, var_ast, opts]}
  end

  defp transform_rhs(_pattern, {:aggregate, _meta, _args} = rhs, _caller) do
    # aggregate already has 3 args, pass through unchanged
    rhs
  end

  defp transform_rhs(_pattern, {:gen, _meta, _args} = rhs, _caller) do
    # gen doesn't need var injection (uses already-bound variables)
    rhs
  end

  defp transform_rhs(_pattern, {:ncc, meta, [[do: block]]}, caller) do
    # ncc do...end - transform the block using normal arrow transformation
    # and wrap in Compose.ncc(...)
    exprs = extract_exprs(block)
    inner_builder = build_bind_chain(exprs, caller)

    {:ncc, meta, [inner_builder]}
  end

  defp transform_rhs(_pattern, rhs, _caller) do
    # Unknown function, pass through unchanged
    rhs
  end

  # Inject var(:name) for SPO (subject, predicate, object) patterns
  # Pattern: {s, p, o} or {:{}, _, [s, p, o]}
  # Args: [s, p, o] or [s, p, o, opts]
  defp inject_vars_for_spo(pattern, args) do
    pattern_elements = extract_tuple_elements(pattern)

    {spo_args, rest_args} = Enum.split(args, 3)

    injected_spo =
      spo_args
      |> Enum.zip(pattern_elements)
      |> Enum.map(fn {arg, pat_elem} ->
        maybe_inject_var(arg, pat_elem)
      end)

    injected_spo ++ rest_args
  end

  # Extract elements from a tuple pattern
  defp extract_tuple_elements({:{}, _, elements}), do: elements
  defp extract_tuple_elements({a, b}), do: [a, b]
  defp extract_tuple_elements({a, b, c}), do: [a, b, c]
  # Single variable pattern (not a tuple)
  defp extract_tuple_elements({name, _, context}) when is_atom(name) and is_atom(context) do
    [{name, [], context}]
  end

  defp extract_tuple_elements(_), do: []

  # Maybe inject var(:name) if arg is :_ and pattern element is a variable
  defp maybe_inject_var(:_, {name, _, context})
       when is_atom(name) and is_atom(context) and name != :_ do
    # Pattern element is a variable, inject var(:name)
    # Strip leading underscore - _name becomes :name for the Var
    var_name = strip_underscore_prefix(name)

    quote do
      var(unquote(var_name))
    end
  end

  defp maybe_inject_var(arg, _pattern_elem) do
    # Keep original arg (literal, already a var(), pinned, etc.)
    arg
  end

  # Extract variable name from a simple variable pattern
  defp extract_single_var_name({name, _, context}) when is_atom(name) and is_atom(context) do
    # Strip leading underscore - _age becomes :age for the Var
    strip_underscore_prefix(name)
  end

  defp extract_single_var_name(other) do
    raise ArgumentError,
          "expected a simple variable pattern for assign, got: #{Macro.to_string(other)}"
  end

  # Strip leading underscore from variable name
  # This allows users to write `_name` to suppress unused variable warnings
  # while still generating `var(:name)` for the Wongi rule
  defp strip_underscore_prefix(name) when is_atom(name) do
    name_str = Atom.to_string(name)

    case name_str do
      "_" <> rest when rest != "" -> String.to_atom(rest)
      _ -> name
    end
  end
end
