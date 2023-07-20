defmodule Wongi.Engine.Filter.LTETest do
  use Wongi.TestCase

  test "matches on less" do
    {rete, ref} =
      new()
      |> compile_and_get_ref(
        rule(
          forall: [
            lte(1, 2)
          ]
        )
      )

    assert [_] = tokens(rete, ref) |> Enum.to_list()
  end

  test "matches on equal" do
    {rete, ref} =
      new()
      |> compile_and_get_ref(
        rule(
          forall: [
            lte(1, 1)
          ]
        )
      )

    assert [_] = tokens(rete, ref) |> Enum.to_list()
  end

  test "does not match on greater" do
    {rete, ref} =
      new()
      |> compile_and_get_ref(
        rule(
          forall: [
            lte(2, 1)
          ]
        )
      )

    assert [] = tokens(rete, ref) |> Enum.to_list()
  end
end
