defmodule Wongi.Scenario do
  @moduledoc false
  # A scenario is a realistic rule set together with a generator of facts from
  # the same domain. Scenarios serve both as worked examples (each has its own
  # test module) and as input to the consistency properties, which exercise
  # every scenario with random sequences of assertions and retractions.
  #
  # The fact generator draws from a small pool of entities, so that random
  # facts collide often enough to make the rules fire.

  alias Wongi.Engine
  alias Wongi.Engine.DSL
  alias Wongi.Engine.Token

  @callback rules() :: [DSL.Rule.t()]
  @callback fact() :: StreamData.t(Wongi.Engine.WME.fact())

  @doc """
  A generator of facts, where each field is either a list of values to pick
  from, or a single literal value.
  """
  def triple(s, p, o) do
    StreamData.tuple({field(s), field(p), field(o)})
  end

  defp field(values) when is_list(values), do: StreamData.member_of(values)
  defp field(value), do: StreamData.constant(value)

  @doc "A fresh engine with all of the scenario's rules."
  def engine(scenario) do
    compile(Engine.new(), scenario.rules())
  end

  def compile(rete, rules) do
    Enum.reduce(rules, rete, &Engine.compile(&2, &1))
  end

  def assert_all(rete, facts) do
    Enum.reduce(facts, rete, &Engine.assert(&2, &1))
  end

  def retract_all(rete, facts) do
    Enum.reduce(facts, rete, &Engine.retract(&2, &1))
  end

  @doc "All facts in the working memory, generated ones included."
  def facts(rete) do
    rete |> Engine.select(:_, :_, :_) |> MapSet.new(&{&1.subject, &1.predicate, &1.object})
  end

  @doc "The objects of the facts matching a subject and predicate."
  def objects(rete, subject, predicate) do
    rete |> Engine.select(subject, predicate, :_) |> Enum.map(& &1.object) |> Enum.sort()
  end

  @doc "The subjects of the facts matching a predicate and object."
  def subjects(rete, predicate, object) do
    rete |> Engine.select(:_, predicate, object) |> Enum.map(& &1.subject) |> Enum.sort()
  end

  @doc """
  Everything observable about the engine's state, in a form that does not
  depend on the order in which it was reached: the facts, and the matches of
  each rule.

  A token after an aggregate inherits the variables of the tokens it
  aggregates, which may bind them differently; which binding is visible then
  depends on the iteration order of its parents. For such rules only the number
  of matches is compared, and their results are compared through the facts
  they generate.
  """
  def observe(rete, rules) do
    matches =
      for rule <- rules, into: %{} do
        tokens = Engine.tokens(rete, rule.ref)

        matches =
          if aggregates?(rule.forall),
            do: Enum.count(tokens),
            else: tokens |> Enum.map(&Token.assignments/1) |> Enum.sort()

        {rule.name, matches}
      end

    %{facts: facts(rete), matches: matches}
  end

  defp aggregates?(clauses) do
    Enum.any?(clauses, fn
      %DSL.Aggregate{} -> true
      %DSL.Any{clauses: branches} -> Enum.any?(branches, &aggregates?/1)
      %DSL.NCC{subchain: subchain} -> aggregates?(subchain)
      _ -> false
    end)
  end
end
