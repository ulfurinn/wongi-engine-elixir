defprotocol Wongi.Engine.Comparable do
  @moduledoc """
  Defines how a struct compares in filters.

  Implement this protocol to control how your struct behaves in `equal`,
  `diff`, `less`, `lte`, `greater`, and `gte`. Implementations return `:lt`,
  `:eq`, `:gt`, or `:unknown` when they cannot compare against the other term.
  Any other return value raises `ArgumentError`.

      defimpl Wongi.Engine.Comparable, for: Money do
        alias Wongi.Engine.Compare

        def compare(%Money{cents: a}, %Money{cents: b}), do: Compare.compare(a, b)
        def compare(%Money{cents: a}, b) when is_integer(b), do: Compare.compare(a, b)
        def compare(%Money{}, _), do: :unknown
      end

  Use `Wongi.Engine.Compare.compare/2` for nested values so that they follow
  the same rules.

  ## Structs without an implementation

  Two values of the same struct type use the module's `compare/2` if it has
  one, following the convention described in `Enum.sort/2`. It must return
  `:lt`, `:eq`, or `:gt`. This covers `Date`, `Time`, `DateTime`,
  `NaiveDateTime`, and `Version`. Without a `compare/2`, the struct's fields are
  compared one by one.

  `Decimal` values need Decimal 2.0 or later, because the `compare/2` in 1.x
  returns a `Decimal` and therefore raises `ArgumentError` here. Comparing a NaN
  raises `Decimal.Error`.

  A module's `compare/2` is never called with a value of another type, because
  functions such as `Date.compare/2` accept other calendar types in only one
  direction, which would make results depend on operand order.

  Don't implement this protocol for those standard library structs, or for
  structs owned by another library, because a second implementation for the
  same type conflicts with the first.

  ## Comparing different types

  When the operands have different types and at least one is a struct, each
  struct is asked about the other, so one implementation works in either
  operand position:

    * if the answers agree, or only one side has an answer, that answer is used
    * if neither side has an answer, term ordering is used
    * if the answers disagree, `ArgumentError` is raised

  ## Non-struct types

  This protocol is only consulted for structs. Implementations for types such
  as `Integer` or `List` are ignored.

  ## Migrating from defcomparable

  Earlier versions used the `comparable` package. Replace each `defcomparable`
  with one `defimpl` per struct. A single implementation covers both operand
  orders, and it should return `:unknown` for unsupported terms.

  Before:

      use Comp

      defcomparable %Money{cents: left} :: Money, right :: Integer do
        Comp.compare(left, right)
      end

  After:

      defimpl Wongi.Engine.Comparable, for: Money do
        alias Wongi.Engine.Compare

        def compare(%Money{} = left, %Money{} = right) do
          Compare.compare(Map.from_struct(left), Map.from_struct(right))
        end

        def compare(%Money{cents: left}, right) when is_integer(right) do
          Compare.compare(left, right)
        end

        def compare(%Money{}, _), do: :unknown
      end

  Keep a same-type clause like the first one if the struct relied on the default
  field comparison. Returning `:unknown` for two values of the implementing type
  means term ordering, which orders nested dates incorrectly.

  Check rules that have the struct as the right operand. `defcomparable` did not
  invert its answer for swapped operands, so the example above returned `:gt`
  for `compare(1, %Money{cents: 2})`. It now correctly returns `:lt`, which can
  change which rules match.
  """

  @fallback_to_any true

  @type result :: :lt | :eq | :gt | :unknown

  @doc "Compares a struct to any term, returning `:unknown` for unsupported terms."
  @spec compare(t, term) :: result
  def compare(left, right)
end

defimpl Wongi.Engine.Comparable, for: Any do
  alias Wongi.Engine.Compare

  def compare(%mod{} = left, %mod{} = right) do
    if Code.ensure_loaded?(mod) and function_exported?(mod, :compare, 2) do
      left |> mod.compare(right) |> validate!(mod)
    else
      compare_fields(left, right)
    end
  end

  def compare(_, _), do: :unknown

  defp compare_fields(left, right) when left == right, do: :eq

  defp compare_fields(left, right) do
    Compare.compare(Map.from_struct(left), Map.from_struct(right))
  end

  defp validate!(result, _) when result in [:lt, :eq, :gt], do: result

  defp validate!(result, mod) do
    raise ArgumentError,
          "expected #{inspect(mod)}.compare/2 to return :lt, :eq, or :gt, got: #{inspect(result)}"
  end
end
