defmodule Wongi.NegTest do
  use ExUnit.Case

  import Wongi.Engine.DSL

  alias Wongi.Engine

  test "triggers on an empty rete" do
    {ref, rete} =
      Engine.new()
      |> Engine.compile_and_get_ref(
        rule(
          forall: [
            neg(:a, :b, :c)
          ]
        )
      )

    assert [_token] = rete |> Engine.tokens(ref) |> MapSet.to_list()

    rete = rete |> Engine.assert([:a, :b, :c])
    assert [] = rete |> Engine.tokens(ref) |> MapSet.to_list()

    rete = rete |> Engine.retract([:a, :b, :c])
    assert [_token] = rete |> Engine.tokens(ref) |> MapSet.to_list()
  end

  test "deactivates on invalidated preconditions" do
    {ref, rete} =
      Engine.new()
      |> Engine.compile_and_get_ref(
        rule(
          forall: [
            has(:x, :y, :z),
            neg(:a, :b, :c)
          ]
        )
      )

    assert [] = rete |> Engine.tokens(ref) |> MapSet.to_list()

    rete = rete |> Engine.assert([:x, :y, :z])
    assert [_token] = rete |> Engine.tokens(ref) |> MapSet.to_list()

    rete = rete |> Engine.retract([:x, :y, :z])
    assert [] = rete |> Engine.tokens(ref) |> MapSet.to_list()
  end

  test "tests against variables" do
    {ref, rete} =
      Engine.new()
      |> Engine.compile_and_get_ref(
        rule(
          forall: [
            has(:a, :b, var(:x)),
            neg(:x, :y, var(:x))
          ]
        )
      )

    rete =
      rete
      |> Engine.assert([:a, :b, 1])
      |> Engine.assert([:x, :y, 1])

    assert [] = rete |> Engine.tokens(ref) |> MapSet.to_list()

    rete =
      rete
      |> Engine.retract([:x, :y, 1])

    assert [_] = rete |> Engine.tokens(ref) |> MapSet.to_list()
  end
end
