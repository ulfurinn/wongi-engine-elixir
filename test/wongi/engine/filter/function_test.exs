defmodule Wongi.Engine.Filter.FunctionTest do
  use Wongi.TestCase

  test "matches on returned true" do
    {rete, ref} =
      new()
      |> compile_and_get_ref(
        rule(
          forall: [
            has(:a, :b, var(:x)),
            filter(&__MODULE__.x_is_true?/1)
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
            has(:a, :b, var(:x)),
            filter(&__MODULE__.x_is_true?/1)
          ]
        )
      )

    rete = rete |> assert(:a, :b, false)
    assert [] = tokens(rete, ref) |> Enum.to_list()
  end

  test "accepts a single variable" do
    {rete, ref} =
      new()
      |> compile_and_get_ref(
        rule(
          forall: [
            has(:a, :b, var(:x)),
            filter(var(:x), &__MODULE__.true?/1)
          ]
        )
      )

    rete = rete |> assert(:a, :b, false)
    assert [] = tokens(rete, ref) |> Enum.to_list()
  end

  test "accepts a variable by name" do
    {rete, ref} =
      new()
      |> compile_and_get_ref(
        rule(
          forall: [
            has(:a, :b, var(:x)),
            filter(:x, &__MODULE__.true?/1)
          ]
        )
      )

    assert [] = rete |> assert(:a, :b, false) |> tokens(ref) |> Enum.to_list()
    assert [_] = rete |> assert(:a, :b, true) |> tokens(ref) |> Enum.to_list()
  end

  test "rejects anything other than a variable" do
    assert_raise ArgumentError, fn -> filter(1, &__MODULE__.true?/1) end
    assert_raise ArgumentError, fn -> filter(nil, &__MODULE__.true?/1) end
  end

  def x_is_true?(token), do: token[:x]

  def true?(true), do: true
  def true?(false), do: false
end
