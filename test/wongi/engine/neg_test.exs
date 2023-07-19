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

  describe "retraction with neg after has" do
    setup do
      {ref, rete} =
        new()
        |> compile_and_get_ref(
          rule(
            forall: [
              has(:x, :u, var(:y)),
              neg(var(:y), :w, any())
            ]
          )
        )

      %{rete: rete, ref: ref}
    end

    test "case 1", %{rete: rete, ref: ref} do
      rete =
        rete
        |> assert(:x, :u, :y)

      assert [_] = rete |> tokens(ref) |> Enum.to_list()

      rete =
        rete
        |> assert(:y, :w, :z)

      assert [] = rete |> tokens(ref) |> Enum.to_list()

      rete =
        rete
        |> retract(:y, :w, :z)

      assert [_] = rete |> tokens(ref) |> Enum.to_list()

      rete =
        rete
        |> retract(:x, :u, :y)

      assert [] = rete |> tokens(ref) |> Enum.to_list()
    end

    test "case 2", %{rete: rete, ref: ref} do
      rete =
        rete
        |> assert(:x, :u, :y)

      assert [_] = rete |> tokens(ref) |> Enum.to_list()

      rete =
        rete
        |> assert(:y, :w, :z)

      assert [] = rete |> tokens(ref) |> Enum.to_list()

      rete =
        rete
        |> retract(:x, :u, :y)

      assert [] = rete |> tokens(ref) |> Enum.to_list()

      rete =
        rete
        |> retract(:y, :w, :z)

      assert [] = rete |> tokens(ref) |> Enum.to_list()
    end

    test "case 3", %{rete: rete, ref: ref} do
      rete =
        rete
        |> assert(:y, :w, :z)

      assert [] = rete |> tokens(ref) |> Enum.to_list()

      rete =
        rete
        |> assert(:x, :u, :y)

      assert [] = rete |> tokens(ref) |> Enum.to_list()

      rete =
        rete
        |> retract(:x, :u, :y)

      assert [] = rete |> tokens(ref) |> Enum.to_list()

      rete =
        rete
        |> retract(:y, :w, :z)

      assert [] = rete |> tokens(ref) |> Enum.to_list()
    end

    test "case 4", %{rete: rete, ref: ref} do
      rete =
        rete
        |> assert(:y, :w, :z)

      assert [] = rete |> tokens(ref) |> Enum.to_list()

      rete =
        rete
        |> assert(:x, :u, :y)

      assert [] = rete |> tokens(ref) |> Enum.to_list()

      rete =
        rete
        |> retract(:y, :w, :z)

      assert [_] = rete |> tokens(ref) |> Enum.to_list()

      rete =
        rete
        |> retract(:x, :u, :y)

      assert [] = rete |> tokens(ref) |> Enum.to_list()
    end
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
