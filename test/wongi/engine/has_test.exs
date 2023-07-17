defmodule Wongi.Engine.HasTest do
  use ExUnit.Case

  import Wongi.Engine.DSL

  alias Wongi.Engine

  test "matches constant facts" do
    {ref, rete} =
      Engine.new()
      |> Engine.compile_and_get_ref(
        rule(
          forall: [
            has(:a, :b, :c)
          ]
        )
      )

    rete =
      rete
      |> Engine.assert([:a, :b, :c])

    assert [_token] =
             rete
             |> Engine.tokens(ref)
             |> MapSet.to_list()
  end

  test "deactivates on retraction" do
    {ref, rete} =
      Engine.new()
      |> Engine.compile_and_get_ref(
        rule(
          forall: [
            has(:a, :b, :c)
          ]
        )
      )

    rete =
      rete
      |> Engine.assert([:a, :b, :c])
      |> Engine.retract([:a, :b, :c])

    assert [] =
             rete
             |> Engine.tokens(ref)
             |> MapSet.to_list()
  end

  test "unifies variables" do
    {ref, rete} =
      Engine.new()
      |> Engine.compile_and_get_ref(
        rule(
          forall: [
            has(:a, var(:x), var(:x))
          ]
        )
      )

    rete =
      rete
      |> Engine.assert([:a, :b, :b])
      |> Engine.assert([:a, :b, :c])

    assert [token] =
             rete
             |> Engine.tokens(ref)
             |> MapSet.to_list()

    assert :b = token[:x]
  end

  test "matches with wildcards" do
    {ref, rete} =
      Engine.new()
      |> Engine.compile_and_get_ref(
        rule(
          forall: [
            has(:a, :b, any())
          ]
        )
      )

    rete =
      rete
      |> Engine.assert([:a, :b, :c])

    assert [_token] =
             rete
             |> Engine.tokens(ref)
             |> MapSet.to_list()
  end

  test "matches with new variables" do
    {ref, rete} =
      Engine.new()
      |> Engine.compile_and_get_ref(
        rule(
          forall: [
            has(:a, :b, var(:x))
          ]
        )
      )

    rete =
      rete
      |> Engine.assert([:a, :b, :c])

    assert [token] =
             rete
             |> Engine.tokens(ref)
             |> MapSet.to_list()

    assert :c = token[:x]
  end

  test "matches with bound variables" do
    {ref, rete} =
      Engine.new()
      |> Engine.compile_and_get_ref(
        rule(
          forall: [
            has(:a, :b, var(:x)),
            has(var(:x), :d, :e)
          ]
        )
      )

    rete =
      rete
      |> Engine.assert([:a, :b, :c])
      |> Engine.assert([:c, :d, :e])

    assert [token] =
             rete
             |> Engine.tokens(ref)
             |> MapSet.to_list()

    assert :c = token[:x]
  end

  test "matches with bound variables when asserted from bottom up" do
    {ref, rete} =
      Engine.new()
      |> Engine.compile_and_get_ref(
        rule(
          forall: [
            has(:a, :b, var(:x)),
            has(var(:x), :d, :e)
          ]
        )
      )

    rete =
      rete
      |> Engine.assert([:c, :d, :e])
      |> Engine.assert([:a, :b, :c])

    assert [token] =
             rete
             |> Engine.tokens(ref)
             |> MapSet.to_list()

    assert :c = token[:x]
  end

  test "deactivates when a precondition is retracted" do
    {ref, rete} =
      Engine.new()
      |> Engine.compile_and_get_ref(
        rule(
          forall: [
            has(:a, :b, var(:x)),
            has(var(:x), :d, :e)
          ]
        )
      )

    rete =
      rete
      |> Engine.assert([:c, :d, :e])
      |> Engine.assert([:a, :b, :c])
      |> Engine.retract([:a, :b, :c])

    assert [] =
             rete
             |> Engine.tokens(ref)
             |> MapSet.to_list()
  end
end
