defmodule Wongi.Engine.HasTest do
  use Wongi.TestCase

  test "matches constant facts" do
    {rete, ref} =
      new()
      |> compile_and_get_ref(
        rule(
          forall: [
            has(:a, :b, :c)
          ]
        )
      )

    rete =
      rete
      |> assert(:a, :b, :c)

    assert [_token] =
             rete
             |> tokens(ref)
             |> MapSet.to_list()
  end

  test "deactivates on retraction" do
    {rete, ref} =
      new()
      |> compile_and_get_ref(
        rule(
          forall: [
            has(:a, :b, :c)
          ]
        )
      )

    rete =
      rete
      |> assert(:a, :b, :c)
      |> retract(:a, :b, :c)

    assert [] =
             rete
             |> tokens(ref)
             |> MapSet.to_list()
  end

  test "unifies variables" do
    {rete, ref} =
      new()
      |> compile_and_get_ref(
        rule(
          forall: [
            has(:a, var(:x), var(:x))
          ]
        )
      )

    rete =
      rete
      |> assert(:a, :b, :b)
      |> assert(:a, :b, :c)

    assert [token] =
             rete
             |> tokens(ref)
             |> MapSet.to_list()

    assert :b = token[:x]
  end

  test "matches with wildcards" do
    {rete, ref} =
      new()
      |> compile_and_get_ref(
        rule(
          forall: [
            has(:a, :b, any())
          ]
        )
      )

    rete =
      rete
      |> assert(:a, :b, :c)

    assert [_token] =
             rete
             |> tokens(ref)
             |> MapSet.to_list()
  end

  test "matches with new variables" do
    {rete, ref} =
      new()
      |> compile_and_get_ref(
        rule(
          forall: [
            has(:a, :b, var(:x))
          ]
        )
      )

    rete =
      rete
      |> assert(:a, :b, :c)

    assert [token] =
             rete
             |> tokens(ref)
             |> MapSet.to_list()

    assert :c = token[:x]
  end

  test "matches with bound variables" do
    {rete, ref} =
      new()
      |> compile_and_get_ref(
        rule(
          forall: [
            has(:a, :b, var(:x)),
            has(var(:x), :d, :e)
          ]
        )
      )

    rete =
      rete
      |> assert(:a, :b, :c)
      |> assert(:c, :d, :e)

    assert [token] =
             rete
             |> tokens(ref)
             |> MapSet.to_list()

    assert :c = token[:x]
  end

  test "matches with bound variables when asserted from bottom up" do
    {rete, ref} =
      new()
      |> compile_and_get_ref(
        rule(
          forall: [
            has(:a, :b, var(:x)),
            has(var(:x), :d, :e)
          ]
        )
      )

    rete =
      rete
      |> assert(:c, :d, :e)
      |> assert(:a, :b, :c)

    assert [token] =
             rete
             |> tokens(ref)
             |> MapSet.to_list()

    assert :c = token[:x]
  end

  test "deactivates when a precondition is retracted" do
    {rete, ref} =
      new()
      |> compile_and_get_ref(
        rule(
          forall: [
            has(:a, :b, var(:x)),
            has(var(:x), :d, :e)
          ]
        )
      )

    rete =
      rete
      |> assert(:c, :d, :e)
      |> assert(:a, :b, :c)
      |> retract(:a, :b, :c)

    assert [] =
             rete
             |> tokens(ref)
             |> Enum.to_list()
  end
end
