defmodule Wongi.Engine.Filter.DiffTest do
  use Wongi.TestCase

  test "matches on unequal" do
    {rete, ref} =
      new()
      |> compile_and_get_ref(
        rule(
          forall: [
            diff(1, 2)
          ]
        )
      )

    assert [_] = tokens(rete, ref) |> Enum.to_list()
  end

  test "does not match on equal" do
    {rete, ref} =
      new()
      |> compile_and_get_ref(
        rule(
          forall: [
            diff(1, 1)
          ]
        )
      )

    assert [] = tokens(rete, ref) |> Enum.to_list()
  end
end
