defmodule Wongi.Engine.AnyTest do
  use Wongi.TestCase

  test "works with one option" do
    {rete, ref} =
      new()
      |> compile_and_get_ref(
        rule(
          forall: [
            has(:a, :b, var(:x)),
            any([
              [
                has(var(:x), :d, :e)
              ]
            ])
          ]
        )
      )

    rete =
      rete
      |> assert(:a, :b, :c)
      |> assert(:c, :d, :e)

    assert [token] = rete |> tokens(ref) |> Enum.to_list()
    assert :c = token[:x]
  end

  test "works with two options" do
    {rete, ref} =
      new()
      |> compile_and_get_ref(
        rule(
          forall: [
            has(:a, :b, var(:x)),
            any([
              [
                has(var(:x), :d, var(:y))
              ],
              [
                has(var(:x), :d, var(:y))
              ]
            ]),
            has(var(:y), :v, :w)
          ]
        )
      )

    rete1 =
      rete
      |> assert(:a, :b, :c)
      |> assert(:c, :d, :e)
      |> assert(:e, :v, :w)

    assert [token] = rete1 |> tokens(ref) |> Enum.to_list()
    assert :c = token[:x]
    assert :e = token[:y]

    rete2 =
      rete
      |> assert(:a, :b, :c)
      |> assert(:c, :d, :f)
      |> assert(:f, :v, :w)

    assert [token] = rete2 |> tokens(ref) |> Enum.to_list()
    assert :c = token[:x]
    assert :f = token[:y]

    rete12 =
      rete
      |> assert(:a, :b, :c)
      |> assert(:c, :d, :e)
      |> assert(:e, :v, :w)
      |> assert(:c, :d, :f)
      |> assert(:f, :v, :w)

    assert [_, _] = tokens = rete12 |> tokens(ref) |> Enum.to_list()
    assert Enum.find(tokens, fn token -> :c == token[:x] and :e == token[:y] end)
    assert Enum.find(tokens, fn token -> :c == token[:x] and :f == token[:y] end)
  end
end
