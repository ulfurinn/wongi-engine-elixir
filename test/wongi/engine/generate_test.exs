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
    assert [_] = select(asserted, :c, :d, :e) |> Enum.to_list()

    retracted =
      asserted
      |> retract(:a, :b, :c)
      |> retract(:c, :d, :e)

    assert [] = select(retracted, :c, :d, :e) |> Enum.to_list()

    assert clean == retracted
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

    assert 3 = rete |> select(:_, :_, :_) |> Enum.count()
    assert [_] = rete |> select(:bob, :friend, :alice) |> Enum.to_list()

    rete =
      rete
      |> retract(:alice, :friend, :bob)

    assert 1 = rete |> select(:_, :_, :_) |> Enum.count()
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

    assert 4 = rete |> select(:_, :_, :_) |> Enum.count()
    assert [_] = rete |> select(:x, :p, :x) |> Enum.to_list()
    assert [_] = rete |> select(:y, :p, :y) |> Enum.to_list()

    rete =
      rete
      |> retract(:x, :p, :y)

    assert 1 = rete |> select(:_, :_, :_) |> Enum.count()
  end

  test "generates and cleans up transitive facts" do
    {clean_rete, ref} =
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

    assert [_] = select(rete_with_facts, :alice, :relative, :charlie) |> Enum.to_list()
    assert [_] = tokens(rete_with_facts, ref) |> Enum.to_list()

    rete_with_one_fact_removed =
      rete_with_facts
      |> retract(:relative, :transitive, true)

    assert [] = select(rete_with_one_fact_removed, :alice, :relative, :charlie) |> Enum.to_list()
    assert [] = tokens(rete_with_one_fact_removed, ref) |> Enum.to_list()

    rete_with_one_fact_removed =
      rete_with_facts
      |> retract(:alice, :relative, :bob)

    assert [] = select(rete_with_one_fact_removed, :alice, :relative, :charlie) |> Enum.to_list()
    assert [] = tokens(rete_with_one_fact_removed, ref) |> Enum.to_list()

    rete_with_one_fact_removed =
      rete_with_facts
      |> retract(:bob, :relative, :charlie)

    assert [] = select(rete_with_one_fact_removed, :alice, :relative, :charlie) |> Enum.to_list()
    assert [] = tokens(rete_with_one_fact_removed, ref) |> Enum.to_list()

    rete_with_all_removed =
      rete_with_facts
      |> retract(:relative, :transitive, true)
      |> retract(:alice, :relative, :bob)
      |> retract(:bob, :relative, :charlie)

    # make sure there are no internal resource leaks
    assert clean_rete == rete_with_all_removed
  end

  test "handles a transitive diamond" do
    {rete, ref} =
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

    assert [_] = rete |> select(:alice, :relative, :dwight) |> Enum.to_list()
    assert 2 = rete |> tokens(ref) |> Enum.count()

    rete = rete |> retract(:claire, :relative, :dwight)
    assert [_] = rete |> select(:alice, :relative, :dwight) |> Enum.to_list()
    assert 1 = rete |> tokens(ref) |> Enum.count()

    rete = rete |> retract(:alice, :relative, :bob)
    assert [] = rete |> select(:alice, :relative, :dwight) |> Enum.to_list()
    assert 0 = rete |> tokens(ref) |> Enum.count()

    rete =
      rete
      |> retract(:bob, :relative, :dwight)
      |> retract(:alice, :relative, :claire)
      |> retract(:relative, :transitive, true)

    assert ^clean_rete = rete
  end

  test "tokens do not get duplicated" do
    {rete, ref} =
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

  test "supports functional generators" do
    rete =
      new()
      |> compile(
        rule(
          forall: [
            has(var(:subject), :dynamic, var(:predicate))
          ],
          do: [
            gen(fn token ->
              [
                {token[:subject], token[:predicate], 1},
                {token[:subject], token[:predicate], 2}
              ]
            end)
          ]
        )
      )
      |> assert(:x, :dynamic, :y)

    assert [_wme] = rete |> select(:x, :y, 1) |> Enum.to_list()
    assert [_wme] = rete |> select(:x, :y, 2) |> Enum.to_list()

    rete = rete |> retract(:x, :dynamic, :y)

    assert [] = rete |> select(:x, :y, 1) |> Enum.to_list()
    assert [] = rete |> select(:x, :y, 2) |> Enum.to_list()
  end

  describe "facts with more than one source" do
    setup do
      {rete, ref} =
        new()
        |> compile(rule(forall: [has(var(:x), :a, true)], do: [gen(var(:x), :q, true)]))
        |> compile(rule(forall: [has(var(:x), :b, true)], do: [gen(var(:x), :q, true)]))
        |> compile_and_get_ref(rule(forall: [has(var(:x), :q, true)]))

      %{rete: rete, ref: ref}
    end

    test "keep their matches when one generator goes", %{rete: rete, ref: ref} do
      rete = rete |> assert(:x, :a, true) |> assert(:x, :b, true) |> retract(:x, :a, true)

      assert [_] = rete |> select(:x, :q, true) |> Enum.to_list()
      assert [_] = rete |> tokens(ref) |> Enum.to_list()
    end

    test "keep their matches when the generator goes but the fact is also asserted", %{
      rete: rete,
      ref: ref
    } do
      rete = rete |> assert(:x, :a, true) |> assert(:x, :q, true) |> retract(:x, :a, true)

      assert [_] = rete |> select(:x, :q, true) |> Enum.to_list()
      assert [_] = rete |> tokens(ref) |> Enum.to_list()
    end

    test "keep their matches when the assertion goes but the fact is still generated", %{
      rete: rete,
      ref: ref
    } do
      rete = rete |> assert(:x, :a, true) |> assert(:x, :q, true) |> retract(:x, :q, true)

      assert [_] = rete |> select(:x, :q, true) |> Enum.to_list()
      assert [_] = rete |> tokens(ref) |> Enum.to_list()
    end
  end

  # These rules compute the transitive closure of :part_of.
  defp direct_membership,
    do: rule(forall: [has(var(:x), :member_of, var(:g))], do: [gen(var(:x), :in, var(:g))])

  defp nested_membership,
    do:
      rule(
        forall: [has(var(:x), :in, var(:g)), has(var(:g), :part_of, var(:h))],
        do: [gen(var(:x), :in, var(:h))]
      )

  test "a rule compiled after the facts sees the facts it generates itself" do
    nested = nested_membership()

    rete =
      new()
      |> assert(:alice, :member_of, :backend)
      |> assert(:backend, :part_of, :everyone)
      |> assert(:everyone, :part_of, :everyone)
      |> compile(direct_membership())
      |> compile(nested)

    assert [_, _] = rete |> tokens(nested.ref) |> Enum.to_list()

    assert [:backend, :everyone] =
             rete |> select(:alice, :in, :_) |> Enum.map(& &1.object) |> Enum.sort()
  end

  test "a fact derived again while it is being retracted is matched once" do
    nested = nested_membership()

    rete =
      new()
      |> compile(direct_membership())
      |> compile(nested)
      |> assert(:dave, :member_of, :backend)
      |> assert(:everyone, :part_of, :everyone)
      |> assert(:everyone, :part_of, :backend)
      |> assert(:backend, :part_of, :everyone)
      |> retract(:everyone, :part_of, :everyone)

    # dave is in :backend, so in :everyone, so in :backend again
    assert [_, _] = rete |> tokens(nested.ref) |> Enum.to_list()
  end

  # The fact generates :located_in, which joins with the fact itself.
  test "the order of rules does not change their matches" do
    direct =
      rule(forall: [has(var(:d), :in_folder, var(:f))], do: [gen(var(:d), :located_in, var(:f))])

    nested = rule(forall: [has(var(:d), :located_in, var(:f)), has(var(:f), :in_folder, var(:o))])

    for rules <- [[direct, nested], [nested, direct]] do
      rete = Enum.reduce(rules, new(), &compile(&2, &1)) |> assert(:ops, :in_folder, :ops)

      assert [_] = rete |> tokens(nested.ref) |> Enum.to_list()
    end
  end

  # The alpha activations of one WME run in the order of the alpha patterns, not
  # of the rule's clauses. When the later clause's pattern comes first, its join
  # sees the token that the earlier clause's join has not yet produced; when it
  # comes second, the earlier join's token reaches it before the WME does.
  for {name, first, second} <- [
        {"parent pattern first", has(var(:x), :b, var(:z)), has(:a, :b, var(:z))},
        {"child pattern first", has(:a, :b, var(:z)), has(var(:x), :b, var(:z))}
      ] do
    test "a WME combines with itself exactly once (#{name})" do
      {rete, ref} =
        new()
        |> compile_and_get_ref(
          rule(forall: [unquote(Macro.escape(first)), unquote(Macro.escape(second))])
        )

      rete = rete |> assert(:a, :b, :c)

      assert [_token] = tokens(rete, ref) |> Enum.to_list()
    end
  end
end
