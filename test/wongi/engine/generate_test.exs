defmodule Wongi.Engine.GenerateTest do
  use Wongi.TestCase

  @transitive [
    forall: [
      has(var(:p), :transitive, true),
      has(var(:x), var(:p), var(:y)),
      has(var(:y), var(:p), var(:z))
    ],
    do: [
      gen(var(:x), var(:p), var(:z))
    ]
  ]

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

  test "generates and cleans up transitive facts" do
    ruledef = @transitive
    {ref, clean_rete} = new() |> compile_and_get_ref(rule(ruledef))

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
