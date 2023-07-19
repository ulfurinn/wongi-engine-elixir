defmodule Wongi.Engine.GenerateTest do
  use Wongi.TestCase

  test "generates and cleans up facts" do
    clean =
      new()
      |> compile(
        rule(
          forall: [has(:a, :b, var(:x)), has(var(:x), :d, :e)],
          do: [gen(var(:x), :generated, true)]
        )
      )

    asserted = clean |> assert(:a, :b, :c) |> assert(:c, :d, :e)
    assert [_] = find(asserted, [:c, :d, :e])

    retracted =
      asserted
      |> retract(:a, :b, :c)
      |> retract(:c, :d, :e)

    assert [] = find(retracted, [:c, :d, :e])

    assert clean.overlay == retracted.overlay
  end

  test "generates symmetric facts" do
    rete =
      new()
      |> compile(
        rule(
          forall: [
            has(var(:p), :symmetric, true),
            has(var(:x), var(:p), var(:y))
          ],
          do: [
            gen(var(:y), var(:p), var(:x))
          ]
        )
      )
      |> assert(:friend, :symmetric, true)
      |> assert(:alice, :friend, :bob)

    assert 3 = rete |> find(:_, :_, :_) |> Enum.count()
    assert [_] = rete |> find(:bob, :friend, :alice) |> Enum.to_list()

    rete =
      rete
      |> retract(:alice, :friend, :bob)

    assert 1 = rete |> find(:_, :_, :_) |> Enum.count()
  end

  test "generates reflexive facts" do
    rete =
      new()
      |> compile(
        rule(
          forall: [
            has(var(:p), :reflexive, true),
            has(var(:x), var(:p), var(:y))
          ],
          do: [
            gen(var(:x), var(:p), var(:x)),
            gen(var(:y), var(:p), var(:y))
          ]
        )
      )
      |> assert(:p, :reflexive, true)
      |> assert(:x, :p, :y)

    assert 4 = rete |> find(:_, :_, :_) |> Enum.count()
    assert [_] = rete |> find(:x, :p, :x) |> Enum.to_list()
    assert [_] = rete |> find(:y, :p, :y) |> Enum.to_list()

    rete =
      rete
      |> retract(:x, :p, :y)

    assert 1 = rete |> find(:_, :_, :_) |> Enum.count()
  end

  test "generates and cleans up transitive facts" do
    {ref, clean_rete} =
      new()
      |> compile_and_get_ref(
        rule(
          forall: [
            has(var(:p), :transitive, true),
            has(var(:x), var(:p), var(:y)),
            has(var(:y), var(:p), var(:z))
          ],
          do: [
            gen(var(:x), var(:p), var(:z))
          ]
        )
      )

    rete_with_facts =
      clean_rete
      |> assert(:relative, :transitive, true)
      |> assert(:alice, :relative, :bob)
      |> assert(:bob, :relative, :charlie)

    assert [_] = find(rete_with_facts, [:alice, :relative, :charlie])
    assert [_] = tokens(rete_with_facts, ref) |> Enum.to_list()

    rete_with_one_fact_removed =
      rete_with_facts
      |> retract(:relative, :transitive, true)

    assert [] = find(rete_with_one_fact_removed, [:alice, :relative, :charlie])
    assert [] = tokens(rete_with_one_fact_removed, ref) |> Enum.to_list()

    rete_with_one_fact_removed =
      rete_with_facts
      |> retract(:alice, :relative, :bob)

    assert [] = find(rete_with_one_fact_removed, [:alice, :relative, :charlie])
    assert [] = tokens(rete_with_one_fact_removed, ref) |> Enum.to_list()

    rete_with_one_fact_removed =
      rete_with_facts
      |> retract(:bob, :relative, :charlie)

    assert [] = find(rete_with_one_fact_removed, [:alice, :relative, :charlie])
    assert [] = tokens(rete_with_one_fact_removed, ref) |> Enum.to_list()

    rete_with_all_removed =
      rete_with_facts
      |> retract(:relative, :transitive, true)
      |> retract(:alice, :relative, :bob)
      |> retract(:bob, :relative, :charlie)

    # make sure there are no internal resource leaks
    assert clean_rete.overlay == rete_with_all_removed.overlay
  end

  test "handles a transitive diamond" do
    {ref, rete} =
      new()
      |> compile_and_get_ref(
        rule(
          forall: [
            has(var(:p), :transitive, true),
            has(var(:x), var(:p), var(:y)),
            has(var(:y), var(:p), var(:z))
          ],
          do: [
            gen(var(:x), var(:p), var(:z))
          ]
        )
      )

    clean_rete = rete

    rete =
      rete
      |> assert(:relative, :transitive, true)
      |> assert(:alice, :relative, :bob)
      |> assert(:bob, :relative, :dwight)
      |> assert(:alice, :relative, :claire)
      |> assert(:claire, :relative, :dwight)

    assert [_] = rete |> find(:alice, :relative, :dwight) |> Enum.to_list()
    assert 2 = rete |> tokens(ref) |> Enum.count()

    rete = rete |> retract(:claire, :relative, :dwight)
    assert [_] = rete |> find(:alice, :relative, :dwight) |> Enum.to_list()
    assert 1 = rete |> tokens(ref) |> Enum.count()

    rete = rete |> retract(:alice, :relative, :bob)
    assert [] = rete |> find(:alice, :relative, :dwight) |> Enum.to_list()
    assert 0 = rete |> tokens(ref) |> Enum.count()

    rete =
      rete
      |> retract(:bob, :relative, :dwight)
      |> retract(:alice, :relative, :claire)
      |> retract(:relative, :transitive, true)

    assert ^clean_rete = rete
  end

  test "tokens do not get duplicated" do
    {ref, rete} =
      new()
      |> compile_and_get_ref(
        rule(
          forall: [
            has(any(), :b, var(:z)),
            has(var(:x), :b, var(:z))
          ]
        )
      )

    rete =
      rete
      |> assert(:a, :b, :c)

    assert [_token] = tokens(rete, ref) |> Enum.to_list()
  end
end
