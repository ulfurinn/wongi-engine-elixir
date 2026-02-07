defmodule Wongi.Engine.DSL.RuleBuilderTest do
  use ExUnit.Case, async: true

  alias Wongi.Engine.DSL.RuleBuilder
  alias Wongi.Engine.DSL.RuleBuilder.Compose
  alias Wongi.Engine.DSL.Rule
  alias Wongi.Engine.DSL.Has
  alias Wongi.Engine.DSL.Neg
  alias Wongi.Engine.DSL.Assign
  alias Wongi.Engine.DSL.Filter
  alias Wongi.Engine.DSL.Var
  alias Wongi.Engine.Action.Generator
  alias Wongi.Engine.Rete

  import Wongi.Engine.DSL, only: [var: 1, greater: 2]

  describe "RuleBuilder core" do
    test "pure wraps value without modifying state" do
      builder = RuleBuilder.pure(:my_value)
      rule = RuleBuilder.run(builder, :test_rule)

      assert rule.name == :test_rule
      assert rule.forall == []
      assert rule.actions == []
    end

    test "bind threads state and passes value to continuation" do
      builder =
        RuleBuilder.pure(1)
        |> RuleBuilder.bind(fn x -> RuleBuilder.pure(x + 1) end)
        |> RuleBuilder.bind(fn x -> RuleBuilder.pure(x * 2) end)

      # We can't directly observe the value, but we can verify state threading
      rule = RuleBuilder.run(builder, :test_rule)
      assert rule.name == :test_rule
    end

    test "run produces Rule struct with correct name and ref" do
      builder = RuleBuilder.pure(:ok)
      rule = RuleBuilder.run(builder, :my_rule)

      assert %Rule{} = rule
      assert rule.name == :my_rule
      assert is_reference(rule.ref)
    end

    test "run reverses forall and actions lists" do
      # Manually build a rule with multiple clauses to verify ordering
      builder =
        Compose.has(var(:a), :pred1, var(:b))
        |> RuleBuilder.bind(fn _ ->
          Compose.has(var(:c), :pred2, var(:d))
        end)
        |> RuleBuilder.bind(fn _ ->
          Compose.gen(var(:a), :result, true)
        end)
        |> RuleBuilder.bind(fn _ ->
          Compose.gen(var(:c), :result, true)
        end)

      rule = RuleBuilder.run(builder, :ordering_test)

      # Forall should be in definition order (first defined = first in list)
      assert [first_has, second_has] = rule.forall
      assert first_has.predicate == :pred1
      assert second_has.predicate == :pred2

      # Actions should also be in definition order
      assert [first_gen, second_gen] = rule.actions
      assert first_gen.template.subject == var(:a)
      assert second_gen.template.subject == var(:c)
    end
  end

  describe "Compose.has/4" do
    test "adds Has clause to forall and yields binding tuple" do
      builder = Compose.has(var(:user), :name, var(:name))
      rule = RuleBuilder.run(builder, :test)

      assert [%Has{} = clause] = rule.forall
      assert clause.subject == var(:user)
      assert clause.predicate == :name
      assert clause.object == var(:name)
    end

    test "supports options like :when" do
      filter = greater(var(:age), 18)
      builder = Compose.has(var(:user), :age, var(:age), when: filter)
      rule = RuleBuilder.run(builder, :test)

      assert [%Has{filters: filters}] = rule.forall
      assert filters == filter
    end

    test "yields {s, p, o} tuple for binding" do
      result =
        Compose.has(var(:user), :name, var(:name))
        |> RuleBuilder.bind(fn {s, p, o} ->
          # Verify we received the binding tuple
          assert s == var(:user)
          assert p == :name
          assert o == var(:name)
          RuleBuilder.pure(:ok)
        end)
        |> RuleBuilder.run(:test)

      assert result.name == :test
    end
  end

  describe "Compose.neg/3" do
    test "adds Neg clause to forall" do
      builder = Compose.neg(var(:user), :deleted, true)
      rule = RuleBuilder.run(builder, :test)

      assert [%Neg{} = clause] = rule.forall
      assert clause.subject == var(:user)
      assert clause.predicate == :deleted
      assert clause.object == true
    end
  end

  describe "Compose.assign/2" do
    test "adds Assign clause and yields the var" do
      value_fn = fn token -> token[:dob] end
      builder = Compose.assign(var(:age), value_fn)
      rule = RuleBuilder.run(builder, :test)

      assert [%Assign{} = clause] = rule.forall
      # Assign.name is stored as an atom (extracted from Var) for consistent token lookups
      assert clause.name == :age
      assert clause.value == value_fn
    end

    test "yields the assigned var for binding" do
      Compose.assign(var(:age), fn _ -> 25 end)
      |> RuleBuilder.bind(fn assigned_var ->
        assert assigned_var == var(:age)
        RuleBuilder.pure(:ok)
      end)
      |> RuleBuilder.run(:test)
    end
  end

  describe "Compose.filter/1" do
    test "adds Filter clause and yields :ok" do
      filter_clause = greater(var(:age), 18)
      builder = Compose.filter(filter_clause)
      rule = RuleBuilder.run(builder, :test)

      assert [%Filter{}] = rule.forall
    end

    test "accepts already-wrapped Filter struct" do
      filter_clause = %Filter{filter: greater(var(:age), 18)}
      builder = Compose.filter(filter_clause)
      rule = RuleBuilder.run(builder, :test)

      assert [%Filter{}] = rule.forall
    end
  end

  describe "Compose.gen/3" do
    test "adds Generator action and yields :ok" do
      builder = Compose.gen(var(:user), :processed, true)
      rule = RuleBuilder.run(builder, :test)

      assert [%Generator{} = action] = rule.actions
      assert action.template.subject == var(:user)
      assert action.template.predicate == :processed
      assert action.template.object == true
    end
  end

  describe "Compose.gen/1 with function" do
    test "adds function-based Generator action" do
      gen_fn = fn token -> {:generated, token[:user], :done} end
      builder = Compose.gen(gen_fn)
      rule = RuleBuilder.run(builder, :test)

      assert [%Generator{generator: ^gen_fn}] = rule.actions
    end
  end

  describe "phase validation" do
    test "raises error when adding has after gen" do
      assert_raise ArgumentError, ~r/forall clause after actions/, fn ->
        Compose.gen(var(:user), :processed, true)
        |> RuleBuilder.bind(fn _ ->
          Compose.has(var(:user), :name, var(:name))
        end)
        |> RuleBuilder.run(:bad_rule)
      end
    end

    test "raises error when adding neg after gen" do
      assert_raise ArgumentError, ~r/forall clause after actions/, fn ->
        Compose.gen(var(:user), :processed, true)
        |> RuleBuilder.bind(fn _ ->
          Compose.neg(var(:user), :deleted, true)
        end)
        |> RuleBuilder.run(:bad_rule)
      end
    end

    test "raises error when adding assign after gen" do
      assert_raise ArgumentError, ~r/forall clause after actions/, fn ->
        Compose.gen(var(:user), :processed, true)
        |> RuleBuilder.bind(fn _ ->
          Compose.assign(var(:x), fn _ -> 1 end)
        end)
        |> RuleBuilder.run(:bad_rule)
      end
    end

    test "raises error when adding filter after gen" do
      assert_raise ArgumentError, ~r/forall clause after actions/, fn ->
        Compose.gen(var(:user), :processed, true)
        |> RuleBuilder.bind(fn _ ->
          Compose.filter(greater(var(:x), 0))
        end)
        |> RuleBuilder.run(:bad_rule)
      end
    end

    test "allows multiple gen actions in sequence" do
      rule =
        Compose.has(var(:user), :name, var(:name))
        |> RuleBuilder.bind(fn _ -> Compose.gen(var(:user), :processed, true) end)
        |> RuleBuilder.bind(fn _ -> Compose.gen(var(:user), :notified, true) end)
        |> RuleBuilder.run(:multi_gen)

      assert length(rule.actions) == 2
    end
  end
end

defmodule Wongi.Engine.DSL.RuleBuilder.SyntaxTest do
  use ExUnit.Case, async: true
  use Wongi.Engine.DSL.RuleBuilder.Syntax

  alias Wongi.Engine.DSL.Has
  alias Wongi.Engine.DSL.Neg
  alias Wongi.Engine.DSL.Assign
  alias Wongi.Engine.DSL.Filter
  alias Wongi.Engine.DSL.Var
  alias Wongi.Engine.Action.Generator
  alias Wongi.Engine.Rete

  # Import filter functions for use in tests (var: 1 is already imported by use Syntax)
  import Wongi.Engine.DSL, only: [greater: 2, var: 1]

  describe "rule macro - basic" do
    test "simple rule with single has clause" do
      r =
        rule :simple do
          {user, _, _name} <- has(:_, :name, :_)
          _ <- gen(user, :greeted, true)
        end

      assert r.name == :simple
      assert [%Has{} = has_clause] = r.forall
      assert has_clause.subject == %Var{name: :user}
      assert has_clause.object == %Var{name: :name}
      assert [%Generator{}] = r.actions
    end

    test "bare gen expression in final position (no arrow bind)" do
      r =
        rule :bare_gen do
          {user, _, _name} <- has(:_, :name, :_)
          gen(user, :greeted, true)
        end

      assert r.name == :bare_gen
      assert [%Has{}] = r.forall
      assert [%Generator{} = gen_action] = r.actions
      assert gen_action.template.predicate == :greeted
    end

    test "bare filter expression in final position" do
      r =
        rule :bare_filter do
          {_user, _, age} <- has(:_, :age, :_)
          filter(greater(age, 18))
        end

      assert r.name == :bare_filter
      assert [%Has{}, %Filter{}] = r.forall
    end

    test "multiple gens with last one bare" do
      r =
        rule :multi_gen_bare do
          {user, _, _} <- has(:_, :active, true)
          _ <- gen(user, :processed, true)
          gen(user, :timestamp, :now)
        end

      assert length(r.actions) == 2
      assert [gen1, gen2] = r.actions
      assert gen1.template.predicate == :processed
      assert gen2.template.predicate == :timestamp
    end

    test "bare expressions work in middle positions too" do
      r =
        rule :all_bare do
          has(:alice, :type, :person)
          neg(:alice, :deleted, true)
          gen(:alice, :valid, true)
        end

      assert [%Has{}, %Neg{}] = r.forall
      assert [%Generator{}] = r.actions
    end

    test "mixed arrow and bare expressions" do
      r =
        rule :mixed do
          {user, _, _} <- has(:_, :type, :person)
          neg(user, :deleted, true)
          {_, _, name} <- has(user, :name, :_)
          gen(user, :greeting, name)
        end

      assert [%Has{}, %Neg{}, %Has{}] = r.forall
      assert [%Generator{}] = r.actions
    end

    test "rule with multiple has clauses and variable reuse" do
      r =
        rule :multi_has do
          {user, _, _name} <- has(:_, :name, :_)
          {_, _, _age} <- has(user, :age, :_)
          _ <- gen(user, :processed, true)
        end

      assert [has1, has2] = r.forall
      assert has1.subject == %Var{name: :user}
      # Second has uses bound user variable (not a new var)
      assert has2.subject == %Var{name: :user}
      assert has2.object == %Var{name: :age}
    end

    test "rule with neg clause" do
      r =
        rule :with_neg do
          {user, _, _} <- has(:_, :active, true)
          {_, _, _} <- neg(user, :deleted, true)
          _ <- gen(user, :valid, true)
        end

      assert [%Has{}, %Neg{} = neg_clause] = r.forall
      assert neg_clause.subject == %Var{name: :user}
      assert neg_clause.predicate == :deleted
    end

    test "rule with assign" do
      r =
        rule :with_assign do
          {user, _, dob} <- has(:_, :dob, :_)
          age <- assign(fn token -> 2024 - token[dob] end)
          _ <- gen(user, :age, age)
        end

      assert [%Has{}, %Assign{} = assign_clause] = r.forall
      # Assign.name is stored as an atom (extracted from Var) for consistent token lookups
      assert assign_clause.name == :age
      assert is_function(assign_clause.value, 1)
    end

    test "rule with filter" do
      r =
        rule :with_filter do
          {user, _, age} <- has(:_, :age, :_)
          _ <- filter(greater(age, 18))
          _ <- gen(user, :adult, true)
        end

      assert [%Has{}, %Filter{}] = r.forall
    end

    test "rule with multiple gen actions" do
      r =
        rule :multi_gen do
          {user, _, _} <- has(:_, :active, true)
          _ <- gen(user, :processed, true)
          _ <- gen(user, :timestamp, :now)
        end

      assert length(r.actions) == 2
      assert [gen1, gen2] = r.actions
      assert gen1.template.predicate == :processed
      assert gen2.template.predicate == :timestamp
    end
  end

  describe "rule macro - complex rules" do
    test "complex rule combining all clause types" do
      r =
        rule :complex do
          {user, _, name} <- has(:_, :name, :_)
          {_, _, age} <- has(user, :age, :_)
          {_, _, _} <- neg(user, :deleted, true)
          _ <- filter(greater(age, 0))
          computed <- assign(fn token -> String.upcase(to_string(token[name])) end)
          _ <- gen(user, :upper_name, computed)
        end

      assert length(r.forall) == 5
      assert [%Has{}, %Has{}, %Neg{}, %Filter{}, %Assign{}] = r.forall
      assert length(r.actions) == 1
    end
  end

  describe "rule macro - Wongi engine integration" do
    test "rule compiles and executes with Rete engine" do
      r =
        rule :integration_test do
          {user, _, _name} <- has(:_, :name, :_)
          _ <- gen(user, :greeted, true)
        end

      engine =
        Rete.new()
        |> Rete.compile(r)
        |> Rete.assert({:alice, :name, "Alice"})
        |> Rete.assert({:bob, :name, "Bob"})

      alice_greeted = Rete.select(engine, :alice, :greeted, :_)
      bob_greeted = Rete.select(engine, :bob, :greeted, :_)

      assert MapSet.size(alice_greeted) == 1
      assert MapSet.size(bob_greeted) == 1
    end

    test "rule with variable reuse works correctly" do
      r =
        rule :variable_reuse do
          {user, _, _} <- has(:_, :type, :person)
          {_, _, name} <- has(user, :name, :_)
          _ <- gen(user, :display_name, name)
        end

      engine =
        Rete.new()
        |> Rete.compile(r)
        |> Rete.assert({:alice, :type, :person})
        |> Rete.assert({:alice, :name, "Alice"})

      results = Rete.select(engine, :alice, :display_name, :_)
      assert MapSet.size(results) == 1

      [wme] = MapSet.to_list(results)
      assert wme.object == "Alice"
    end

    test "rule with neg prevents firing when negative condition matches" do
      r =
        rule :neg_test do
          {user, _, _} <- has(:_, :active, true)
          {_, _, _} <- neg(user, :deleted, true)
          _ <- gen(user, :valid, true)
        end

      # User without deleted flag - rule should fire
      engine1 =
        Rete.new()
        |> Rete.compile(r)
        |> Rete.assert({:alice, :active, true})

      assert MapSet.size(Rete.select(engine1, :alice, :valid, :_)) == 1

      # User with deleted flag - rule should not fire
      engine2 =
        Rete.new()
        |> Rete.compile(r)
        |> Rete.assert({:bob, :active, true})
        |> Rete.assert({:bob, :deleted, true})

      assert MapSet.size(Rete.select(engine2, :bob, :valid, :_)) == 0
    end

    test "rule with assign computes values correctly" do
      r =
        rule :assign_test do
          {user, _, birth_year} <- has(:_, :birth_year, :_)
          age <- assign(fn token -> 2024 - token[birth_year] end)
          _ <- gen(user, :age, age)
        end

      engine =
        Rete.new()
        |> Rete.compile(r)
        |> Rete.assert({:alice, :birth_year, 1990})

      results = Rete.select(engine, :alice, :age, :_)
      assert MapSet.size(results) == 1

      [wme] = MapSet.to_list(results)
      assert wme.object == 34
    end
  end

  describe "compatibility with old DSL" do
    test "produces same structure as old DSL" do
      alias Wongi.Engine.DSL, as: OldDSL

      # Old DSL (using fully qualified name to avoid conflict)
      old_rule =
        OldDSL.rule(:old_style,
          forall: [
            OldDSL.has(var(:user), :name, var(:name))
          ],
          do: [
            OldDSL.gen(var(:user), :greeted, true)
          ]
        )

      # New DSL
      new_rule =
        rule :new_style do
          {user, _, _name} <- has(:_, :name, :_)
          _ <- gen(user, :greeted, true)
        end

      # Same structure
      assert length(old_rule.forall) == length(new_rule.forall)
      assert length(old_rule.actions) == length(new_rule.actions)

      # Same clause types
      [old_has] = old_rule.forall
      [new_has] = new_rule.forall
      assert old_has.__struct__ == new_has.__struct__
      assert old_has.subject == new_has.subject
      assert old_has.predicate == new_has.predicate
      assert old_has.object == new_has.object
    end

    test "both DSLs produce rules that behave identically" do
      alias Wongi.Engine.DSL, as: OldDSL

      old_rule =
        OldDSL.rule(:old_style,
          forall: [
            OldDSL.has(var(:user), :type, :person),
            OldDSL.has(var(:user), :name, var(:name))
          ],
          do: [
            OldDSL.gen(var(:user), :processed, true)
          ]
        )

      new_rule =
        rule :new_style do
          {user, _, _} <- has(:_, :type, :person)
          {_, _, _name} <- has(user, :name, :_)
          _ <- gen(user, :processed, true)
        end

      # Test with same data
      facts = [
        {:alice, :type, :person},
        {:alice, :name, "Alice"},
        {:bob, :type, :person},
        {:bob, :name, "Bob"}
      ]

      engine_old =
        Enum.reduce(facts, Rete.new() |> Rete.compile(old_rule), fn fact, eng ->
          Rete.assert(eng, fact)
        end)

      engine_new =
        Enum.reduce(facts, Rete.new() |> Rete.compile(new_rule), fn fact, eng ->
          Rete.assert(eng, fact)
        end)

      # Same results
      old_results = Rete.select(engine_old, :_, :processed, true)
      new_results = Rete.select(engine_new, :_, :processed, true)

      assert MapSet.size(old_results) == MapSet.size(new_results)
      assert MapSet.size(old_results) == 2
    end
  end
end

defmodule Wongi.Engine.DSL.RuleBuilder.DefruleTest do
  use ExUnit.Case, async: true
  use Wongi.Engine.DSL.RuleBuilder.Syntax

  alias Wongi.Engine.DSL.Has
  alias Wongi.Engine.DSL.Var
  alias Wongi.Engine.Action.Generator
  alias Wongi.Engine.Rete

  # Import filter functions
  import Wongi.Engine.DSL, only: [greater: 2, var: 1]

  # Define parameterized rules using defrule
  defrule greet_by_type(entity_type) do
    {entity, _, _} <- has(:_, :type, entity_type)
    _ <- gen(entity, :greeted, true)
  end

  defrule mark_entity(entity_type, output_pred, output_value) do
    {entity, _, _} <- has(:_, :type, entity_type)
    _ <- gen(entity, output_pred, output_value)
  end

  defrule filter_by_threshold(pred, threshold) do
    {entity, _, value} <- has(:_, pred, :_)
    _ <- filter(greater(value, threshold))
    _ <- gen(entity, :above_threshold, true)
  end

  defrule no_args_rule() do
    {entity, _, _} <- has(:_, :exists, true)
    _ <- gen(entity, :found, true)
  end

  describe "defrule macro" do
    test "creates a function that returns a rule" do
      rule = greet_by_type(:person)

      assert rule.name == :greet_by_type
      assert [%Has{} = has_clause] = rule.forall
      assert has_clause.predicate == :type
      assert has_clause.object == :person
      assert [%Generator{}] = rule.actions
    end

    test "different parameters create different rules" do
      rule1 = greet_by_type(:person)
      rule2 = greet_by_type(:robot)

      assert rule1.name == :greet_by_type
      assert rule2.name == :greet_by_type

      [has1] = rule1.forall
      [has2] = rule2.forall

      assert has1.object == :person
      assert has2.object == :robot
    end

    test "multiple parameters work" do
      rule = mark_entity(:order, :processed, :done)

      assert rule.name == :mark_entity
      [has_clause] = rule.forall
      assert has_clause.object == :order

      [gen] = rule.actions
      assert gen.template.predicate == :processed
      assert gen.template.object == :done
    end

    test "parameters can be used in filter expressions" do
      rule = filter_by_threshold(:score, 100)

      assert rule.name == :filter_by_threshold
      # has + filter
      assert length(rule.forall) == 2
    end

    test "zero-arg defrule works" do
      rule = no_args_rule()

      assert rule.name == :no_args_rule
      assert [%Has{}] = rule.forall
    end

    test "defrule integrates with Rete engine" do
      engine =
        Rete.new()
        |> Rete.compile(greet_by_type(:person))
        |> Rete.assert({:alice, :type, :person})
        |> Rete.assert({:robot1, :type, :robot})

      # Only alice should be greeted (person type)
      alice_greeted = Rete.select(engine, :alice, :greeted, true)
      robot_greeted = Rete.select(engine, :robot1, :greeted, true)

      assert MapSet.size(alice_greeted) == 1
      assert MapSet.size(robot_greeted) == 0

      # Now add the robot rule
      engine =
        engine
        |> Rete.compile(greet_by_type(:robot))

      robot_greeted = Rete.select(engine, :robot1, :greeted, true)
      assert MapSet.size(robot_greeted) == 1
    end

    test "multiple defrule instances can coexist" do
      engine =
        Rete.new()
        |> Rete.compile(mark_entity(:person, :human, true))
        |> Rete.compile(mark_entity(:robot, :machine, true))
        |> Rete.assert({:alice, :type, :person})
        |> Rete.assert({:r2d2, :type, :robot})

      assert MapSet.size(Rete.select(engine, :alice, :human, true)) == 1
      assert MapSet.size(Rete.select(engine, :alice, :machine, true)) == 0
      assert MapSet.size(Rete.select(engine, :r2d2, :machine, true)) == 1
      assert MapSet.size(Rete.select(engine, :r2d2, :human, true)) == 0
    end
  end
end
