defmodule Wongi.Engine.Figter.GTETest do
  use Wongi.TestCase

  test "matches on greater" do
    {rete, ref} =
      new()
      |> compile_and_get_ref(
        rule(
          forall: [
            gte(2, 1)
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
            gte(1, 1)
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
            gte(1, 2)
          ]
        )
      )

    assert [] = tokens(rete, ref) |> Enum.to_list()
  end
end
