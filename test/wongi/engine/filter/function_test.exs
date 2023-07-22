defmodule Wongi.Engine.Filter.FunctionTest do
  use Wongi.TestCase

  test "matches on returned true" do
    {rete, ref} =
      new()
      |> compile_and_get_ref(
        rule(
          forall: [
            has(:a, :b, var(:x)),
            filter(&__MODULE__.true?/1)
          ]
        )
      )

    rete = rete |> assert(:a, :b, true)
    assert [_] = tokens(rete, ref) |> Enum.to_list()
  end

  test "does not match on returned false" do
    {rete, ref} =
      new()
      |> compile_and_get_ref(
        rule(
          forall: [
            diff(1, 1)
          ]
        )
      )

    rete = rete |> assert(:a, :b, false)
    assert [] = tokens(rete, ref) |> Enum.to_list()
  end

  def true?(token), do: token[:x]
end
