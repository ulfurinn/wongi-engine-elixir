since code is cheap these days...

here's a for-discussion implementation of the alt-DSL syntax I proposed in [Issue 36](https://github.com/ulfurinn/wongi-engine-elixir/issues/36)

UPDATE: it got to be a bit more than a quick spike - there's `ncc` and `any` support now too 😸

UPDATE: added an `action` clause for action functions, and some better error messages when an expected `RuleBuilder` isn't returned - I think this is complete now... I'm going to trial it on some of our rulesets

what do you think ?

-----------

## Proposed Syntax

Using a monadic pattern with arrow binding (similar to Haskell's `do` notation or Elixir's `with`):

```elixir
rule :calculate_age do
  {user, _, name} <- has(:_, :name, :_)
  {_, _, year} <- has(user, :birth_year, :_)
  age <- assign(fn token -> 2024 - token[year] end)
  gen(user, :age, age)
end
```

**Key features:**
- Pattern matching on the left binds real Elixir variables
- `:_` placeholders in DSL calls are replaced with `var(:name)` based on the pattern
- Variables are properly scoped - typos become compile errors
- Full LSP support (autocomplete, rename, go-to-definition)
- Cleaner visual flow of the rule logic

## How It Works

The macro transforms each line:

```elixir
# This:
{user, _, name} <- has(:_, :name, :_)

# Becomes (conceptually):
RuleBuilder.bind(
  has(var(:user), :name, var(:name)),
  fn {user, _, name} -> ...
end)
```

The pattern `{user, _, name}` tells the macro:
- Position 0 has variable `user` → inject `var(:user)` where `:_` appears
- Position 1 is `_` → leave predicate as-is
- Position 2 has variable `name` → inject `var(:name)` where `:_` appears

## Syntax Examples

### Basic Rule

```elixir
rule :greet_users do
  {user, _, _} <- has(:_, :type, :person)
  gen(user, :greeted, true)
end
```

### Variable Reuse (Join)

```elixir
rule :user_with_email do
  {user, _, _} <- has(:_, :type, :person)
  {_, _, email} <- has(user, :email, :_)  # 'user' reused from above
  gen(user, :has_email, email)
end
```

### Negative Match

```elixir
rule :active_users do
  {user, _, _} <- has(:_, :active, true)
  neg(user, :deleted, true)  # No binding needed
  gen(user, :valid, true)
end
```

### Computed Values with Assign

```elixir
rule :calculate_age do
  {user, _, birth_year} <- has(:_, :birth_year, :_)
  age <- assign(fn token -> 2024 - token[birth_year] end)
  gen(user, :age, age)
end
```

Note: `birth_year` is a real Elixir variable holding `%Var{name: :birth_year}`, so `token[birth_year]` works naturally.

### Filters

Using built-in filter functions:

```elixir
rule :adults_only do
  {user, _, age} <- has(:_, :age, :_)
  filter(greater(age, 18))
  gen(user, :adult, true)
end
```

With a custom function (arity-1, receives full token):

```elixir
rule :complex_filter do
  {user, _, age} <- has(:_, :age, :_)
  filter(fn token -> token[:age] > 18 and token[:age] < 65 end)
  gen(user, :working_age, true)
end
```

With a variable and function (arity-2, var resolved and passed to function):

```elixir
rule :simple_filter do
  {user, _, age} <- has(:_, :age, :_)
  filter(age, fn a -> a > 18 end)
  gen(user, :adult, true)
end
```

### Aggregates

Compute values across multiple tokens with optional partitioning:

```elixir
rule :find_lightest do
  {_fruit, _, weight} <- has(:_, :weight, :_)
  min_weight <- aggregate(&Enum.min/1, over: weight)
  {lightest, _, _} <- has(:_, :weight, min_weight)
  gen(lightest, :is_lightest, true)
end
```

With partitioning (group by):

```elixir
rule :total_by_category do
  {item, _, category} <- has(:_, :category, :_)
  {_, _, weight} <- has(item, :weight, :_)
  total <- aggregate(&Enum.sum/1, over: weight, partition: [category])
  gen(category, :total_weight, total)
end
```

### Negated Conjunctive Conditions (NCC)

Match only when an entire subchain does NOT match:

```elixir
rule :no_deleted_chain do
  {user, _, _} <- has(:_, :active, true)

  ncc do
    {_, _, reason} <- has(user, :deleted, :_)
    {_, _, _} <- has(reason, :confirmed, true)
  end

  gen(user, :valid, true)
end
```

The rule fires when `user` is active AND there is no `(user, :deleted, reason)` with `(reason, :confirmed, true)`. Variables inside `ncc` can reference outer variables but don't export new bindings.

### Disjunctions (Any)

Match when ANY branch matches, with variables exported to outer context:

```elixir
rule :match_type do
  {x, _, _} <- has(:_, :entity, true)

  %{y: y} <- any do
    branch do
      {_, _, y} <- has(x, :type_a, :_)
    end
    branch do
      {_, _, y} <- has(x, :type_b, :_)
      _ <- filter(greater(y, 10))
    end
  end

  # y is extracted directly via pattern matching on the vars map
  gen(x, :matched_type, y)
end
```

Key differences from `ncc`:
- Variables ARE exported (via the `vars` map)
- All branches should bind consistent variable names
- Rule fires when ANY branch matches (not when NONE match)

### Multiple Actions

```elixir
rule :process_order do
  {order, _, _} <- has(:_, :type, :order)
  {_, _, total} <- has(order, :total, :_)
  gen(order, :processed, true)
  gen(order, :processed_at, DateTime.utc_now())
end
```

### Custom Actions with `action`

For side effects that don't generate facts, use `action` with a function:

**2-arity function (execute only)** - called when the rule fires:

```elixir
rule :log_activations do
  {user, _, _} <- has(:_, :active, true)
  action(fn token, rete ->
    Logger.info("User activated: #{token[user]}")
    rete
  end)
end
```

**3-arity function (execute + deexecute)** - called on both assertion and retraction:

```elixir
rule :track_active_users do
  {user, _, _} <- has(:_, :active, true)
  action(fn action_type, token, rete ->
    case action_type do
      :execute -> ExternalTracker.add(token[user])
      :deexecute -> ExternalTracker.remove(token[user])
    end
    rete
  end)
end
```

The 3-arity form is useful for maintaining external state that needs cleanup when facts are retracted. The function receives:
- `action_type` - `:execute` on assertion, `:deexecute` on retraction
- `token` - the matched token
- `rete` - the engine state

The function may return an updated `%Rete{}` struct or any other value (which keeps the original rete).

### Parameterized Rules with `defrule`

For reusable rule templates:

```elixir
defrule process_entity(entity_type, output_pred) do
  {entity, _, _} <- has(:_, :type, entity_type)
  gen(entity, output_pred, true)
end

# Usage:
engine
|> Rete.compile(process_entity(:person, :greeted))
|> Rete.compile(process_entity(:order, :processed))
```

### Pure Assignments with `=`

Regular Elixir `=` bindings work inside rule blocks for intermediate computations:

```elixir
rule :with_computed_values do
  {entity, _, value} <- has(:_, :score, :_)
  threshold = 100
  doubled = threshold * 2
  filter(greater(value, doubled))
  label = "high_scorer_#{threshold}"
  gen(entity, :status, label)
end
```

These are plain Elixir assignments (no monadic bind), useful for:
- Computing intermediate values from parameters or constants
- String interpolation and formatting
- Any pure computation that doesn't involve the DSL

### Bare Expressions (No Arrow)

When you don't need the binding, skip the arrow:

```elixir
rule :simple do
  has(:alice, :type, :person)  # No variables to bind
  neg(:alice, :deleted, true)
  gen(:alice, :active, true)
end
```

### Mixed Style

```elixir
rule :mixed do
  {user, _, _} <- has(:_, :type, :person)  # Need 'user' binding
  neg(user, :banned, true)                  # Just a check
  {_, _, name} <- has(user, :name, :_)      # Need 'name' binding
  gen(user, :display_name, name)
end
```

## Pattern Rules

| Pattern Element | Meaning                                                          |
|-----------------|------------------------------------------------------------------|
| `user`          | Bind variable, inject `var(:user)` at `:_` position              |
| `_`             | Wildcard, no binding                                             |
| `_name`         | Bind to `_name` (suppresses unused warning), inject `var(:name)` |
| `^user`         | Pin existing variable (test, not bind)                           |
| `:literal`      | Literal value, no injection                                      |

## Benefits

1. **Type Safety**: Variables are real Elixir bindings - typos are compile errors
2. **IDE Support**: Full LSP integration (autocomplete, rename, find references)
3. **Readability**: Rule logic flows naturally top-to-bottom
4. **Familiarity**: Similar to `with`, `for`, and other Elixir constructs
5. **Flexibility**: Mix arrow and bare syntax as needed
6. **Composability**: `defrule` enables parameterized rule factories

## Compatibility

- Produces identical `%Rule{}` structs as the existing DSL
- Works with the existing Rete engine unchanged
- Can coexist with the current DSL (different module)

## Implementation

The implementation uses a State monad pattern:
- `RuleBuilder` struct wraps a function `RuleBuilderState -> {value, RuleBuilderState}`
- `RuleBuilderState` holds the Rule being built, plus builder-internal fields (`mode`, `bound_vars`)
- DSL functions (`has`, `neg`, `gen`, etc.) return `RuleBuilder` values
- `bind` chains operations, threading the RuleBuilderState
- `run` executes the chain and produces the final `%Rule{}` (without builder-internal fields)

### Matcher-Only Mode for NCC and Any

Both `ncc` and `any` contain subchains that should only have matchers (no actions). The RuleBuilder supports this via:

1. **Mode field**: `RuleBuilderState` struct has `mode: :full | :matcher_only` (internal to RuleBuilder, not exposed on final Rule)
2. **Action validation**: `gen` and other actions check mode and raise if `:matcher_only`
3. **`run_matcher_only/1`**: Executes a builder in matcher-only mode, returning `{clauses, bound_vars}`

```elixir
# Compose.ncc/1 uses run_matcher_only:
def ncc(%RuleBuilder{} = builder) do
  {clauses, _bound_vars} = RuleBuilder.run_matcher_only(builder)
  forall_clause(NCC.new(clauses), :ok)
end
```

### Variable Tracking

`RuleBuilderState` tracks `bound_vars` (a MapSet of atom names) during rule construction. This is internal builder state, not exposed on the final Rule struct. The tracking enables `any` to collect all variables from all branches and return them as a map:

```elixir
# Compose.any/1 collects vars from all branches:
def any(branches) when is_list(branches) do
  {branch_clauses, all_vars} =
    Enum.reduce(branches, {[], MapSet.new()}, fn builder, {clauses_acc, vars_acc} ->
      {clauses, bound_vars} = RuleBuilder.run_matcher_only(builder)
      {[clauses | clauses_acc], MapSet.union(vars_acc, bound_vars)}
    end)

  vars_map = Map.new(all_vars, fn name -> {name, %Var{name: name}} end)
  forall_clause(Any.new(Enum.reverse(branch_clauses)), vars_map)
end
```

### Syntax Transformation for Nested Blocks

The `Syntax` module transforms `ncc do...end` and `any do...branch...end` blocks:

1. **Extract inner expressions** from the do-block
2. **Transform using `build_bind_chain`** (same as top-level rule body)
3. **Wrap in appropriate Compose function** (`ncc` or `any`)

For `any`, each `branch do...end` is extracted and transformed separately:

```elixir
defp extract_and_transform_branches(block, caller) do
  exprs = extract_exprs(block)
  Enum.map(exprs, fn
    {:branch, _, [[do: branch_block]]} ->
      branch_exprs = extract_exprs(branch_block)
      build_bind_chain(branch_exprs, caller)
    other ->
      raise ArgumentError, "expected `branch do...end` inside `any do...end`"
  end)
end
```

This reuses the full arrow transformation machinery, so variables bind naturally within branches.

~700 lines of code total across:
- `RuleBuilder` (core monad + matcher-only mode)
- `RuleBuilder.Compose` (DSL functions including ncc, any, aggregate)
- `RuleBuilder.Syntax` (macros + nested block transformation)

## Status

Fully implemented and tested:
- Core `rule` macro
- `defrule` for parameterized rules
- `has`, `neg`, `assign`, `filter`, `gen`
- `action` for custom function actions (2-arity and 3-arity with execute/deexecute)
- `aggregate` with `over:` and `partition:` options
- `ncc do...end` (negated conjunctive conditions)
- `any do...branch...end` (disjunctions with variable export)
- 88 tests covering all syntax variants and engine integration
