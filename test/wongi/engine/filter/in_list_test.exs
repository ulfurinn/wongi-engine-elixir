defmodule Wongi.Engine.Filter.InListTest do
  use Wongi.TestCase

  test "matches when in list" do
    {rete, ref} =
      new()
      |> compile_and_get_ref(
        rule(
          forall: [
            in_list(1, [1, 2, 3])
          ]
        )
      )

    assert [_] = tokens(rete, ref) |> Enum.to_list()
  end

  test "does not match when not in list" do
    {rete, ref} =
      new()
      |> compile_and_get_ref(
        rule(
          forall: [
            in_list(4, [1, 2, 3])
          ]
        )
      )

    assert [] = tokens(rete, ref) |> Enum.to_list()
  end
end
