defmodule Wongi.Engine.Compiler.ReorderTest do
  use Wongi.TestCase

  alias Wongi.Engine.Compiler.Reorder
  alias Wongi.Scenario

  defp foralls(rules), do: rules |> Reorder.reorder() |> Enum.map(& &1.forall)

  test "puts shared clauses first" do
    a = has(var(:x), :a, var(:y))
    b = has(var(:x), :b, var(:z))
    c = has(var(:x), :c, var(:w))

    assert [[^a, ^b, ^c], [^a, ^b]] =
             foralls([
               rule(forall: [a, c, b]),
               rule(forall: [b, a])
             ])
  end

  test "leaves a rule that shares nothing as it is" do
    clauses = [has(var(:x), :a, var(:y)), has(var(:y), :b, var(:z))]
    other = [has(var(:p), :c, var(:q))]

    assert [^clauses, ^other] = foralls([rule(forall: clauses), rule(forall: other)])
  end

  test "keeps the refs of the rules" do
    rules = [rule(forall: [has(:a, :b, :c)]), rule(forall: [has(:a, :b, :c)])]
    assert Enum.map(rules, & &1.ref) == rules |> Reorder.reorder() |> Enum.map(& &1.ref)
  end

  test "does not move a filter before its variables are bound" do
    a = has(var(:x), :a, var(:y))
    b = has(var(:x), :b, var(:z))
    f = greater(var(:z), 1)

    assert [[^b, ^a, ^f], [^b, ^a]] =
             foralls([
               rule(forall: [b, f, a]),
               rule(forall: [a, b])
             ])
  end

  test "shares filters" do
    a = has(var(:x), :a, var(:y))
    b = has(var(:x), :b, var(:z))
    f = greater(var(:y), 1)

    assert [[^a, ^f, ^b], [^a, ^f]] =
             foralls([
               rule(forall: [a, b, f]),
               rule(forall: [a, f])
             ])
  end

  test "does not move a match before the variables of its filters are bound" do
    a = has(var(:x), :a, var(:y))
    b = has(var(:x), :b, var(:z), when: [greater(var(:z), var(:y))])
    c = has(var(:x), :c, var(:w))

    assert [[^c, ^a, ^b], [^c]] =
             foralls([
               rule(forall: [a, b, c]),
               rule(forall: [c])
             ])
  end

  test "does not move a filter that uses a variable bound after it" do
    a = has(var(:x), :a, var(:y))
    f = equal(var(:z), nil)
    b = has(var(:x), :b, var(:z))

    assert [[^a, ^f, ^b], [^b]] =
             foralls([
               rule(forall: [a, f, b]),
               rule(forall: [b])
             ])
  end

  test "does not move anything across a barrier" do
    a = has(var(:x), :a, var(:y))
    b = has(var(:x), :b, var(:z))
    n = neg(var(:y), :c, :_)

    assert [[^a, ^n, ^b], [^b]] =
             foralls([
               rule(forall: [a, n, b]),
               rule(forall: [b])
             ])
  end

  test "shares clauses after a shared barrier" do
    a = has(var(:x), :a, var(:y))
    b = has(var(:x), :b, var(:z))
    c = has(var(:x), :c, var(:w))
    n = neg(var(:y), :c, :_)

    assert [[^a, ^n, ^c, ^b], [^a, ^n, ^c]] =
             foralls([
               rule(forall: [a, n, b, c]),
               rule(forall: [a, n, c])
             ])
  end

  test "prefers clauses that join with the bound variables" do
    a = has(var(:x), :a, var(:y))
    b = has(var(:x), :b, var(:z))
    u = has(var(:p), :u, var(:q))

    # u is shared by all three, but would be a cross product after a
    assert [[^a, ^b, ^u], [^a, ^b, ^u], [^a, ^u]] =
             foralls([
               rule(forall: [a, u, b]),
               rule(forall: [u, a, b]),
               rule(forall: [a, u])
             ])
  end

  test "shares a cross product that cannot be avoided" do
    a = has(var(:x), :a, var(:y))
    u = has(var(:p), :u, var(:q))

    assert [[^a, ^u], [^a, ^u]] = foralls([rule(forall: [a, u]), rule(forall: [u, a])])
  end

  test "keeps the rest of a rule joined after its shared clauses" do
    a = has(var(:x), :a, var(:y))
    b = has(var(:y), :b, var(:z))
    c = has(var(:z), :c, var(:w))

    # a would be a cross product after c
    assert [[^c, ^b, ^a], [^c]] = foralls([rule(forall: [a, b, c]), rule(forall: [c])])
  end

  test "shares more nodes" do
    a = has(var(:x), :a, var(:y))
    b = has(var(:x), :b, var(:z))
    c = has(var(:x), :c, var(:w))

    rules = [rule(forall: [a, b, c]), rule(forall: [c, b, a]), rule(forall: [b, c])]

    plain = new() |> compile_all(rules)
    reordered = new() |> compile_all(rules, reorder: true)

    # root, 3 + 3 + 2 joins and a production each, or 3 joins shared by all
    assert map_size(plain.beta_table) == 1 + 8 + 3
    assert map_size(reordered.beta_table) == 1 + 3 + 3
  end

  test "matches the same" do
    a = has(var(:x), :a, var(:y))
    b = has(var(:x), :b, var(:z))
    rules = [rule(forall: [a, b]), rule(forall: [b, a, greater(var(:z), var(:y))])]

    facts = [{:o, :a, 1}, {:o, :b, 2}, {:p, :a, 3}, {:p, :b, 1}]

    plain = new() |> compile_all(rules) |> Scenario.assert_all(facts)
    reordered = new() |> compile_all(rules, reorder: true) |> Scenario.assert_all(facts)

    for rule <- rules do
      assert plain |> tokens(rule.ref) |> Enum.map(&Token.assignments/1) |> Enum.sort() ==
               reordered |> tokens(rule.ref) |> Enum.map(&Token.assignments/1) |> Enum.sort()
    end
  end
end
