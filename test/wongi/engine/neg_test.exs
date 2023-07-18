defmodule Wongi.Engine.NegTest do
  use Wongi.TestCase

  test "triggers on an empty rete" do
    {ref, rete} =
      new()
      |> compile_and_get_ref(
        rule(
          forall: [
            neg(:a, :b, :c)
          ]
        )
      )

    assert [_token] = rete |> tokens(ref) |> Enum.to_list()

    rete = rete |> assert(:a, :b, :c)
    assert [] = rete |> tokens(ref) |> Enum.to_list()

    rete = rete |> retract([:a, :b, :c])
    assert [_token] = rete |> tokens(ref) |> Enum.to_list()
  end

  test "deactivates on invalidated preconditions" do
    {ref, rete} =
      new()
      |> compile_and_get_ref(
        rule(
          forall: [
            has(:x, :y, :z),
            neg(:a, :b, :c)
          ]
        )
      )

    assert [] = rete |> tokens(ref) |> Enum.to_list()

    rete = rete |> assert(:x, :y, :z)
    assert [_token] = rete |> tokens(ref) |> Enum.to_list()

    rete = rete |> retract(:x, :y, :z)
    assert [] = rete |> tokens(ref) |> Enum.to_list()
  end

  test "tests against variables" do
    {ref, rete} =
      new()
      |> compile_and_get_ref(
        rule(
          forall: [
            has(:a, :b, var(:x)),
            neg(:x, :y, var(:x))
          ]
        )
      )

    rete =
      rete
      |> assert(:a, :b, 1)
      |> assert(:x, :y, 1)

    assert [] = rete |> tokens(ref) |> Enum.to_list()

    rete =
      rete
      |> retract(:x, :y, 1)

    assert [_] = rete |> tokens(ref) |> Enum.to_list()
  end

  test "unifies variables" do
    {ref, rete} =
      new()
      |> compile_and_get_ref(
        rule(
          forall: [
            has(:a, :b, var(:x)),
            neg(var(:x), var(:y), var(:y))
          ]
        )
      )

    rete = rete |> assert(:a, :b, :c)
    assert [_] = rete |> tokens(ref) |> Enum.to_list()

    rete = rete |> assert(:c, :d, :e)
    assert [_] = rete |> tokens(ref) |> Enum.to_list()

    rete = rete |> assert(:c, :d, :d)
    assert [] = rete |> tokens(ref) |> Enum.to_list()
  end
end
