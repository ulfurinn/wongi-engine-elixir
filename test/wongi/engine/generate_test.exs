defmodule Wongi.Engine.GenerateTest do
  use ExUnit.Case

  import Wongi.Engine.DSL

  alias Wongi.Engine

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
      Engine.new()
      |> Engine.compile(
        rule(
          forall: [has(:a, :b, var(:x)), has(var(:x), :d, :e)],
          do: [gen(var(:x), :generated, true)]
        )
      )

    asserted = clean |> Engine.assert(:a, :b, :c) |> Engine.assert(:c, :d, :e)
    assert [_] = Engine.find(asserted, [:c, :d, :e])

    retracted =
      asserted
      |> Engine.retract(:a, :b, :c)
      |> Engine.retract(:c, :d, :e)

    assert [] = Engine.find(retracted, [:c, :d, :e])

    assert clean.overlay == retracted.overlay
  end

  test "generates and cleans up transitive facts" do
    ruledef = @transitive
    {ref, clean_rete} = Engine.new() |> Engine.compile_and_get_ref(rule(ruledef))

    rete_with_facts =
      clean_rete
      |> Engine.assert(:relative, :transitive, true)
      |> Engine.assert(:alice, :relative, :bob)
      |> Engine.assert(:bob, :relative, :charlie)

    assert [_] = Engine.find(rete_with_facts, [:alice, :relative, :charlie])
    assert [_] = Engine.tokens(rete_with_facts, ref) |> Enum.to_list()

    rete_with_one_fact_removed =
      rete_with_facts
      |> Engine.retract(:relative, :transitive, true)

    assert [] = Engine.find(rete_with_one_fact_removed, [:alice, :relative, :charlie])
    assert [] = Engine.tokens(rete_with_one_fact_removed, ref) |> Enum.to_list()

    rete_with_one_fact_removed =
      rete_with_facts
      |> Engine.retract(:alice, :relative, :bob)

    assert [] = Engine.find(rete_with_one_fact_removed, [:alice, :relative, :charlie])
    assert [] = Engine.tokens(rete_with_one_fact_removed, ref) |> Enum.to_list()

    rete_with_one_fact_removed =
      rete_with_facts
      |> Engine.retract(:bob, :relative, :charlie)

    assert [] = Engine.find(rete_with_one_fact_removed, [:alice, :relative, :charlie])
    assert [] = Engine.tokens(rete_with_one_fact_removed, ref) |> Enum.to_list()

    rete_with_all_removed =
      rete_with_facts
      |> Engine.retract(:relative, :transitive, true)
      |> Engine.retract(:alice, :relative, :bob)
      |> Engine.retract(:bob, :relative, :charlie)

    # make sure there are no internal resource leaks
    assert clean_rete.overlay == rete_with_all_removed.overlay
  end
end
