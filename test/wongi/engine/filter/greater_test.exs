defmodule Wongi.Engine.Filter.GreaterTest do
  use Wongi.TestCase

  test "matches on greater" do
    {rete, ref} =
      new()
      |> compile_and_get_ref(
        rule(
          forall: [
            greater(2, 1)
          ]
        )
      )

    assert [_] = tokens(rete, ref) |> Enum.to_list()
  end

  test "does not match on less" do
    {rete, ref} =
      new()
      |> compile_and_get_ref(
        rule(
          forall: [
            greater(1, 2)
          ]
        )
      )

    assert [] = tokens(rete, ref) |> Enum.to_list()
  end

  test "does not match on equal" do
    {rete, ref} =
      new()
      |> compile_and_get_ref(
        rule(
          forall: [
            greater(1, 1)
          ]
        )
      )

    assert [] = tokens(rete, ref) |> Enum.to_list()
  end
end
