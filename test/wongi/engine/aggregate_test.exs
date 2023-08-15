defmodule Wongi.Engine.AggregateTest do
  use Wongi.TestCase

  alias Wongi.Engine.Aggregates

  describe "min" do
    test "calculates the minimum" do
      {rete, ref} =
        new()
        |> compile_and_get_ref(
          rule(
            forall: [
              has(:_, :weight, var(:weight)),
              aggregate(&Aggregates.min/1, :x, over: :weight),
              has(var(:fruit), :weight, var(:x))
            ]
          )
        )

      initial = rete

      rete = rete |> assert(:apple, :weight, 5)
      assert [token] = rete |> tokens(ref) |> Enum.to_list()
      assert :apple = token[:fruit]
      assert 5 = token[:x]

      rete = rete |> assert(:pea, :weight, 2)
      assert [token] = rete |> tokens(ref) |> Enum.to_list()
      assert :pea = token[:fruit]
      assert 2 = token[:x]

      rete = rete |> retract(:pea, :weight, 2)
      assert [token] = rete |> tokens(ref) |> Enum.to_list()
      assert :apple = token[:fruit]
      assert 5 = token[:x]

      rete = rete |> retract(:apple, :weight, 5)
      assert [] = rete |> tokens(ref) |> Enum.to_list()
      assert initial == rete
    end

    test "calculates the maximum" do
      {rete, ref} =
        new()
        |> compile_and_get_ref(
          rule(
            forall: [
              has(:_, :weight, var(:weight)),
              aggregate(&Aggregates.max/1, :x, over: :weight),
              has(var(:fruit), :weight, var(:x))
            ]
          )
        )

      initial = rete

      rete = rete |> assert(:pea, :weight, 2)
      assert [token] = rete |> tokens(ref) |> Enum.to_list()
      assert :pea = token[:fruit]
      assert 2 = token[:x]

      rete = rete |> assert(:apple, :weight, 5)
      assert [token] = rete |> tokens(ref) |> Enum.to_list()
      assert 5 = token[:x]
      assert :apple = token[:fruit]

      rete = rete |> retract(:apple, :weight, 5)
      assert [token] = rete |> tokens(ref) |> Enum.to_list()
      assert :pea = token[:fruit]
      assert 2 = token[:x]

      rete = rete |> retract(:pea, :weight, 2)
      assert [] = rete |> tokens(ref) |> Enum.to_list()
      assert initial == rete
    end
  end

  test "calculates the count" do
    {rete, ref} =
      new()
      |> compile_and_get_ref(
        rule(
          forall: [
            has(:_, :weight, var(:weight)),
            aggregate(&Enum.count/1, :count, over: :weight)
          ]
        )
      )

    rete = rete |> assert(:pea, :weight, 2)
    assert [token] = rete |> tokens(ref) |> Enum.to_list()
    assert 1 = token[:count]

    rete = rete |> assert(:apple, :weight, 5)
    assert [token] = rete |> tokens(ref) |> Enum.to_list()
    assert 2 = token[:count]
  end

  test "partitions by a single var" do
    {rete, ref} =
      new()
      |> compile_and_get_ref(
        rule(
          forall: [
            has(:factor, var(:number), var(:factor)),
            aggregate(&Aggregates.product/1, :product, over: :factor, partition: :number)
          ]
        )
      )

    rete =
      rete
      |> assert(:factor, 10, 2)
      |> assert(:factor, 10, 5)
      |> assert(:factor, 12, 3)
      |> assert(:factor, 12, 4)

    assert [t1, t2] = rete |> tokens(ref) |> Enum.to_list()
    assert t1[:number] == t1[:product]
    assert t2[:number] == t2[:product]
  end

  test "partitions by a list" do
    {rete, ref} =
      new()
      |> compile_and_get_ref(
        rule(
          forall: [
            has(:factor, var(:number), var(:factor)),
            aggregate(&Aggregates.product/1, :product, over: :factor, partition: [:number])
          ]
        )
      )

    rete =
      rete
      |> assert(:factor, 10, 2)
      |> assert(:factor, 10, 5)
      |> assert(:factor, 12, 3)
      |> assert(:factor, 12, 4)

    assert [t1, t2] = rete |> tokens(ref) |> Enum.to_list()
    assert t1[:number] == t1[:product]
    assert t2[:number] == t2[:product]
  end
end
