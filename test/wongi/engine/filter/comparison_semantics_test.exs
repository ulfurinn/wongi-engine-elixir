defmodule Wongi.Engine.Filter.ComparisonSemanticsTest do
  use Wongi.TestCase

  alias Wongi.Engine.Filter
  alias Wongi.Engine.Filter.Diff
  alias Wongi.Engine.Filter.Equal
  alias Wongi.Engine.Filter.Greater
  alias Wongi.Engine.Filter.GTE
  alias Wongi.Engine.Filter.Less
  alias Wongi.Engine.Filter.LTE
  alias Wongi.Test.Comparables.ConflictA
  alias Wongi.Test.Comparables.ConflictB
  alias Wongi.Test.Comparables.Money

  defmodule Plain do
    @moduledoc false
    defstruct [:a, :b]
  end

  @cases [
    {"integer and float", 1, 1.0, :eq},
    {"integer and float in list", [1], [1.0], :eq},
    {"integer and float in map value", %{a: 1}, %{a: 1.0}, :eq},
    {"integer and float map keys", %{1 => :x}, %{1.0 => :x}, :eq},
    {"dates", ~D[2024-02-01], ~D[2024-01-31], :gt},
    {"dates in list", [~D[2024-02-01]], [~D[2024-01-31]], :gt},
    {"dates in tuple", {~D[2024-02-01]}, {~D[2024-01-31]}, :gt},
    {"dates in map", %{a: ~D[2024-02-01]}, %{a: ~D[2024-01-31]}, :gt},
    {"time precision", ~T[12:00:00.0], ~T[12:00:00.000], :eq},
    {"date and datetime", ~D[2024-01-01], ~U[2024-01-01 00:00:00Z], :lt},
    {"nil and integer", nil, 1, :gt},
    {"atom and string", :a, "a", :lt},
    {"list prefix", [1], [1, 2], :lt},
    {"empty list", [], [1], :lt},
    {"tuple size wins", {9}, {1, 2}, :lt},
    {"map size wins", %{a: 9}, %{a: 1, b: 2}, :lt},
    {"struct and plain map", %URI{}, %{}, :gt},
    {"unknown struct module", %{__struct__: :nope, a: 2}, %{__struct__: :nope, a: 1}, :gt},
    {"improper list differing head", [1 | 2], [2 | 3], :lt}
  ]

  for {name, left, right, expected} <- @cases do
    test "orders #{name}" do
      left = unquote(Macro.escape(left))
      right = unquote(Macro.escape(right))

      assert order(left, right) == unquote(expected)
    end
  end

  test "orders struct fields semantically" do
    assert order(%Plain{a: ~D[2024-02-01]}, %Plain{a: ~D[2024-01-31]}) == :gt
  end

  test "treats the same instant in different zones as equal" do
    paris = %{
      ~U[2024-01-01 13:00:00Z]
      | utc_offset: 3600,
        zone_abbr: "CET",
        time_zone: "Europe/Paris"
    }

    assert order(paris, ~U[2024-01-01 12:00:00Z]) == :eq
  end

  test "raises on improper lists with equal heads" do
    assert_raise FunctionClauseError, fn -> order([1 | 2], [1 | 3]) end
  end

  test "orders structs with compare/2 semantically" do
    assert order(Version.parse!("1.0.0"), Version.parse!("1.0.0-rc1")) == :gt
  end

  test "honors custom implementations in either operand position" do
    assert order(%Money{cents: 2}, 1) == :gt
    assert order(1, %Money{cents: 2}) == :lt
    assert order(%Money{cents: 2}, 2) == :eq
    assert order(2, %Money{cents: 2}) == :eq
  end

  test "raises on conflicting custom implementations" do
    assert_raise ArgumentError, fn -> order(%ConflictA{}, %ConflictB{}) end
  end

  test "matches a custom struct in a compiled rule" do
    {rete, ref} =
      new()
      |> compile_and_get_ref(
        rule(
          forall: [
            has(:x, :y, var(:z)),
            equal(var(:z), 2)
          ]
        )
      )

    rete = rete |> assert(:x, :y, %Money{cents: 2})

    assert [_] = tokens(rete, ref) |> Enum.to_list()
  end

  defp order(a, b) do
    eq = pass?(Equal, a, b)
    lt = pass?(Less, a, b)
    gt = pass?(Greater, a, b)

    assert Enum.count([lt, eq, gt], & &1) == 1
    assert pass?(Diff, a, b) == not eq
    assert pass?(LTE, a, b) == (lt or eq)
    assert pass?(GTE, a, b) == (gt or eq)

    cond do
      eq -> :eq
      lt -> :lt
      gt -> :gt
    end
  end

  defp pass?(filter, a, b), do: Filter.pass?(filter.new(a, b), nil)
end
