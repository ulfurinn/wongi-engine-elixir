defmodule Wongi.Scenarios.ConsistencyTest do
  # The engine updates its state incrementally, so the state it reaches must
  # not depend on the path it took to get there. Each property checks this for
  # every scenario by comparing an engine that went through a random sequence of
  # assertions and retractions with an engine built from scratch from the facts
  # that are left at the end.
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Wongi.Engine
  alias Wongi.Scenario

  # PROPERTY_RUNS=10000 mix test test/wongi/scenarios for a longer run
  @runs String.to_integer(System.get_env("PROPERTY_RUNS", "100"))
  @moduletag timeout: :infinity

  @scenarios [
    Wongi.Scenarios.DocumentAccess,
    Wongi.Scenarios.OrderFulfilment,
    Wongi.Scenarios.ProjectTracking,
    Wongi.Scenarios.RoomBooking
  ]

  # An operation on the working memory. Retracting a fact chosen at random will
  # mostly hit facts that are not there, so most retractions pick one of the
  # facts asserted so far instead, by position.
  defp operation(scenario) do
    StreamData.frequency([
      {6, StreamData.tuple({StreamData.constant(:assert), scenario.fact()})},
      {1, StreamData.tuple({StreamData.constant(:retract), scenario.fact()})},
      {3, StreamData.tuple({StreamData.constant(:retract_asserted), StreamData.integer(0..1000)})}
    ])
  end

  defp operations(scenario) do
    StreamData.list_of(operation(scenario), max_length: 60)
  end

  # Applies an operation to both the engine and the set of facts that are
  # expected to remain asserted.
  defp apply_operation({:assert, fact}, {rete, facts}),
    do: {Engine.assert(rete, fact), MapSet.put(facts, fact)}

  defp apply_operation({:retract, fact}, {rete, facts}),
    do: {Engine.retract(rete, fact), MapSet.delete(facts, fact)}

  defp apply_operation({:retract_asserted, n}, {rete, facts}) do
    case Enum.sort(facts) do
      [] ->
        {rete, facts}

      asserted ->
        apply_operation({:retract, Enum.at(asserted, rem(n, length(asserted)))}, {rete, facts})
    end
  end

  defp shuffle(list, seed) do
    :rand.seed(:exsss, seed)
    Enum.shuffle(list)
  end

  # The order of the rules matters to the engine too, as it decides the order
  # in which nodes are activated, so it is shuffled as well.
  defp from_scratch(rules, facts, seed) do
    Engine.new()
    |> Scenario.compile(shuffle(rules, seed))
    |> Scenario.assert_all(shuffle(Enum.to_list(facts), seed))
  end

  for scenario <- @scenarios do
    @scenario scenario

    describe inspect(scenario) do
      property "every step agrees with an engine built from scratch" do
        check all(ops <- operations(@scenario), seed <- StreamData.integer(), max_runs: @runs) do
          rules = @scenario.rules()
          clean = Scenario.compile(Engine.new(), rules)

          Enum.reduce(ops, {clean, MapSet.new()}, fn op, state ->
            {rete, facts} = apply_operation(op, state)

            assert Scenario.observe(rete, rules) ==
                     Scenario.observe(from_scratch(rules, facts, seed), rules)

            {rete, facts}
          end)
        end
      end

      property "retracting everything returns to the initial state" do
        check all(ops <- operations(@scenario), seed <- StreamData.integer(), max_runs: @runs) do
          rules = @scenario.rules()
          clean = Scenario.compile(Engine.new(), rules)

          {rete, facts} = Enum.reduce(ops, {clean, MapSet.new()}, &apply_operation/2)
          rete = Scenario.retract_all(rete, shuffle(Enum.to_list(facts), seed))

          assert Scenario.facts(rete) == MapSet.new()
          assert rete == clean
        end
      end

      property "rules compiled at any point agree with rules compiled first" do
        check all(
                ops <- operations(@scenario),
                points <-
                  StreamData.list_of(StreamData.integer(0..60), length: length(@scenario.rules())),
                seed <- StreamData.integer(),
                max_runs: @runs
              ) do
          rules = @scenario.rules()

          # Each rule is compiled just before the operation at its point, or
          # after the last one if the point is past the end.
          schedule = rules |> Enum.zip(points) |> Enum.group_by(&elem(&1, 1), &elem(&1, 0))

          {rete, facts} =
            ops
            |> Enum.with_index()
            |> Enum.reduce({Engine.new(), MapSet.new()}, fn {op, i}, {rete, facts} ->
              rete = Scenario.compile(rete, Map.get(schedule, i, []))
              apply_operation(op, {rete, facts})
            end)

          late = for {point, rules} <- schedule, point >= length(ops), rule <- rules, do: rule
          rete = Scenario.compile(rete, late)

          assert Scenario.observe(rete, rules) ==
                   Scenario.observe(from_scratch(rules, facts, seed), rules)
        end
      end
    end
  end
end
