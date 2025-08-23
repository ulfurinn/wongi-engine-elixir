defmodule Wongi.Engine.AggregateTest do
  use Wongi.TestCase

  describe "min" do
    test "calculates the minimum" do
      {rete, ref} =
        new()
        |> compile_and_get_ref(
          rule(
            forall: [
              has(:_, :weight, var(:weight)),
              aggregate(&min/1, :x, over: :weight),
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
              aggregate(&max/1, :x, over: :weight),
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

  test "calculates the sum" do
    {rete, ref} =
      new()
      |> compile_and_get_ref(
        rule(
          forall: [
            has(:_, :weight, var(:weight)),
            aggregate(&sum/1, :sum, over: :weight)
          ]
        )
      )

    rete = rete |> assert(:pea, :weight, 2)
    assert [token] = rete |> tokens(ref) |> Enum.to_list()
    assert 2 = token[:sum]

    rete = rete |> assert(:apple, :weight, 5)
    assert [token] = rete |> tokens(ref) |> Enum.to_list()
    assert 7 = token[:sum]
  end

  test "partitions by a single var" do
    {rete, ref} =
      new()
      |> compile_and_get_ref(
        rule(
          forall: [
            has(:factor, var(:number), var(:factor)),
            aggregate(&product/1, :product, over: :factor, partition: :number)
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
            aggregate(&product/1, :product, over: :factor, partition: [:number])
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

  describe "issue 20" do
    # https://github.com/ulfurinn/wongi-engine-elixir/issues/20
    test "wme state is consistent with token state" do
      rete =
        new()
        |> compile(
          rule(
            forall: [
              has(var(:s), :p, var(:o)),
              aggregate(&min/1, :min, over: :o, partition: :s)
            ],
            do: [
              gen(var(:s), :min, var(:min))
            ]
          )
        )
        |> compile(
          rule(
            forall: [
              has(:_, :min, var(:value)),
              aggregate(&Enum.to_list/1, :collected, over: :value)
            ],
            do: [
              gen(:total, :collected, var(:collected))
            ]
          )
        )
        |> assert(:a, :p, 1)
        |> assert(:b, :p, 2)

      # Assert: single result; was producing multiple ones before the fix
      assert [result] = rete |> select(:_, :collected, :_) |> Enum.to_list()
      assert Enum.sort(result.object) == [1, 2]
    end
  end
end
