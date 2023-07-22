defmodule Wongi.Engine.Filter.EmbeddedTest do
  use Wongi.TestCase

  describe "embedded filters on join nodes" do
    test "single filter" do
      {rete, ref} =
        new()
        |> compile_and_get_ref(
          rule(
            forall: [
              has(:a, :b, var(:c), when: greater(var(:c), 9))
            ]
          )
        )

      rete = rete |> assert(:a, :b, 9)
      assert [] = rete |> tokens(ref) |> Enum.to_list()

      rete = rete |> assert(:a, :b, 11)
      assert [token] = rete |> tokens(ref) |> Enum.to_list()
      assert 11 = token[:c]
    end

    test "a list of filters" do
      {rete, ref} =
        new()
        |> compile_and_get_ref(
          rule(
            forall: [
              has(:a, :b, var(:c), when: [greater(var(:c), 9), less(var(:c), 11)])
            ]
          )
        )

      rete = rete |> assert(:a, :b, 9)
      assert [] = rete |> tokens(ref) |> Enum.to_list()

      rete = rete |> assert(:a, :b, 11)
      assert [] = rete |> tokens(ref) |> Enum.to_list()

      rete = rete |> assert(:a, :b, 10)
      assert [token] = rete |> tokens(ref) |> Enum.to_list()
      assert 10 = token[:c]
    end
  end
end
