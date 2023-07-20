defmodule Wongi.Engine.Filter.EqualTest do
  use Wongi.TestCase

  test "matches on equal constants" do
    {rete, ref} =
      new()
      |> compile_and_get_ref(
        rule(
          forall: [
            equal(1, 1)
          ]
        )
      )

    assert [_] = tokens(rete, ref) |> Enum.to_list()
  end

  test "does not match on unequal constants" do
    {rete, ref} =
      new()
      |> compile_and_get_ref(
        rule(
          forall: [
            equal(1, 2)
          ]
        )
      )

    assert [] = tokens(rete, ref) |> Enum.to_list()
  end

  test "matches on equal variable and constant" do
    {rete, ref} =
      new()
      |> compile_and_get_ref(
        rule(
          forall: [
            has(:x, :y, var(:z)),
            equal(var(:z), 1)
          ]
        )
      )

    rete = rete |> assert(:x, :y, 1)

    assert [token] = tokens(rete, ref) |> Enum.to_list()
    assert 1 = token[:z]
  end

  test "matches on equal constant and variable" do
    {rete, ref} =
      new()
      |> compile_and_get_ref(
        rule(
          forall: [
            has(:x, :y, var(:z)),
            equal(1, var(:z))
          ]
        )
      )

    rete = rete |> assert(:x, :y, 1)

    assert [token] = tokens(rete, ref) |> Enum.to_list()
    assert 1 = token[:z]
  end

  test "does not match unequal variable and constant" do
    {rete, ref} =
      new()
      |> compile_and_get_ref(
        rule(
          forall: [
            has(:x, :y, var(:z)),
            equal(var(:z), 1)
          ]
        )
      )

    rete = rete |> assert(:x, :y, 2)

    assert [] = tokens(rete, ref) |> Enum.to_list()
  end

  test "matches on two equal variables" do
    {rete, ref} =
      new()
      |> compile_and_get_ref(
        rule(
          forall: [
            has(:x, :y, var(:z)),
            has(:u, :v, var(:w)),
            equal(var(:z), var(:w))
          ]
        )
      )

    rete =
      rete
      |> assert(:x, :y, 1)
      |> assert(:u, :v, 1)

    assert [token] = tokens(rete, ref) |> Enum.to_list()
    assert 1 = token[:z]
    assert 1 = token[:w]
  end

  test "does not match on two unequal variable" do
    {rete, ref} =
      new()
      |> compile_and_get_ref(
        rule(
          forall: [
            has(:x, :y, var(:z)),
            has(:u, :v, var(:w)),
            equal(var(:z), var(:w))
          ]
        )
      )

    rete =
      rete
      |> assert(:x, :y, 1)
      |> assert(:u, :v, 2)

    assert [] = tokens(rete, ref) |> Enum.to_list()
  end
end
