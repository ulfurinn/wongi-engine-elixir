defmodule Wongi.Engine.Filter.LessTest do
  use Wongi.TestCase

  test "matches on less" do
    {rete, ref} =
      new()
      |> compile_and_get_ref(
        rule(
          forall: [
            less(1, 2)
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
            less(2, 1)
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
            less(1, 1)
          ]
        )
      )

    assert [] = tokens(rete, ref) |> Enum.to_list()
  end
end
