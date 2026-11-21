defmodule Wongi.Engine.CompareTest do
  use ExUnit.Case, async: true

  import Wongi.Engine.Compare, only: [compare: 2]

  alias Wongi.Test.Comparables.BadCompare
  alias Wongi.Test.Comparables.BadImpl
  alias Wongi.Test.Comparables.ConflictA
  alias Wongi.Test.Comparables.ConflictB
  alias Wongi.Test.Comparables.Declining
  alias Wongi.Test.Comparables.Money
  alias Wongi.Test.Comparables.Plain
  alias Wongi.Test.Comparables.RaisingCompare
  alias Wongi.Test.Comparables.Reversed

  describe "custom implementations" do
    test "answer for either operand position" do
      assert compare(%Money{cents: 2}, 1) == :gt
      assert compare(1, %Money{cents: 2}) == :lt
    end

    test "apply inside collections and struct fields" do
      assert compare([%Money{cents: 1}], [%Money{cents: 2}]) == :lt
      assert compare({%Money{cents: 1}}, {%Money{cents: 2}}) == :lt
      assert compare(%{a: %Money{cents: 1}}, %{a: %Money{cents: 2}}) == :lt
      assert compare(%Plain{a: %Money{cents: 1}}, %Plain{a: %Money{cents: 2}}) == :lt
    end

    test "use term ordering when declining their own type" do
      assert compare(%Declining{d: ~D[2024-02-01]}, %Declining{d: ~D[2024-01-31]}) == :lt
    end

    test "are ignored for non-struct types" do
      assert compare(1, 1) == :eq
    end

    test "raise on an invalid return" do
      assert_raise ArgumentError, fn -> compare(%BadImpl{}, %BadImpl{}) end
    end

    test "raise when cross-type answers disagree, in either operand order" do
      assert_raise ArgumentError, ~r/ConflictA.*ConflictB/, fn ->
        compare(%ConflictA{}, %ConflictB{})
      end

      assert_raise ArgumentError, ~r/ConflictB.*ConflictA/, fn ->
        compare(%ConflictB{}, %ConflictA{})
      end
    end
  end

  describe "structs without an implementation" do
    test "compare fields when the module has no compare/2" do
      assert compare(%Plain{a: ~D[2024-02-01]}, %Plain{a: ~D[2024-01-31]}) == :gt
    end

    test "are equal when their fields hold equal improper lists" do
      assert compare(%Plain{a: [1 | 2]}, %Plain{a: [1 | 2]}) == :eq
      assert compare(%Plain{a: [1 | 2]}, %Plain{a: [1.0 | 2]}) == :eq
      assert compare([%Plain{a: [1 | 2]}], [%Plain{a: [1 | 2]}]) == :eq
      assert compare(%{__struct__: :nope, a: [1 | 2]}, %{__struct__: :nope, a: [1 | 2]}) == :eq
    end

    test "delegate to the module's compare/2" do
      assert compare(%Reversed{rank: 1}, %Reversed{rank: 2}) == :gt
      assert compare(Version.parse!("1.0.0"), Version.parse!("1.0.0-rc1")) == :gt
    end

    test "raise when compare/2 breaks the convention" do
      assert_raise ArgumentError, fn ->
        compare(%BadCompare{value: true}, %BadCompare{value: true})
      end

      assert_raise ArgumentError, fn ->
        compare(%BadCompare{value: :unknown}, %BadCompare{value: :unknown})
      end
    end

    test "propagate exceptions from compare/2" do
      assert_raise RuntimeError, fn -> compare(%RaisingCompare{}, %RaisingCompare{}) end
    end
  end

  describe "across struct types" do
    test "does not delegate between calendar types" do
      assert compare(~D[2024-01-01], ~U[2024-01-01 12:00:00Z]) == :lt
      assert compare(~U[2024-01-01 12:00:00Z], ~D[2024-01-01]) == :gt
      assert compare(~T[12:00:00], ~U[2024-01-01 12:00:00Z]) == :lt
      assert compare(~U[2024-01-01 12:00:00Z], ~T[12:00:00]) == :gt
    end

    test "does not delegate to Version for strings" do
      assert compare(Version.parse!("1.2.3"), "1.2.3") == :lt
      assert compare("1.2.3", Version.parse!("1.2.3")) == :gt
    end
  end
end
