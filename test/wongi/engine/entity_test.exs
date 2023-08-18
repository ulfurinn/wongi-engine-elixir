defmodule Wongi.Engine.EntityTest do
  use Wongi.TestCase

  test "returns objects by property name" do
    subject = make_ref()

    rete =
      new()
      |> assert(subject, :a, 1)
      |> assert(subject, :a, 2)
      |> assert(subject, :b, 3)
      |> assert(subject, :c, 4)

    iterator = rete |> entity(subject)

    assert 3 == iterator[:b]
    assert 4 == iterator[:c]
    assert nil != iterator[:a]
    assert nil == iterator[:x]
  end

  test "Enumerable.reduce/3" do
    subject = make_ref()

    rete =
      new()
      |> assert(subject, :a, 1)
      |> assert(subject, :b, 2)
      |> assert(subject, :c, 3)

    list = rete |> entity(subject) |> Enum.to_list()
    assert Keyword.equal?(list, a: 1, b: 2, c: 3)
  end

  test "Enumerable.member?/2" do
    subject = make_ref()

    rete =
      new()
      |> assert(subject, :a, 1)

    iterator = rete |> entity(subject)

    assert true == :a in iterator
    assert false == :b in iterator

    assert true == {:a, 1} in iterator
    assert false == {:a, 2} in iterator
  end
end
