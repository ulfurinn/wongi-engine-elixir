# Compares rules compiled as written with rules reordered by compile_all/3.
#
#   MIX_ENV=test mix run bench/rule_ordering.exs
#
# The scenarios live in test/support, which is only compiled in the test
# environment.

defmodule Bench.RuleOrdering do
  use Wongi.Engine.DSL

  alias Wongi.Engine
  alias Wongi.Scenario

  @runs 3

  @scenarios [
    Wongi.Scenarios.DocumentAccess,
    Wongi.Scenarios.OrderFulfilment,
    Wongi.Scenarios.ProjectTracking,
    Wongi.Scenarios.RoomBooking
  ]

  def run do
    :rand.seed(:exsss, 42)

    scenario_rules = Enum.flat_map(@scenarios, & &1.rules())
    scenario_facts = Enum.flat_map(@scenarios, &Enum.take(&1.fact(), 150))

    corpora =
      [
        {"scenarios", scenario_rules, scenario_facts},
        {"scenarios, shuffled", Scenario.shuffle_matches(scenario_rules), scenario_facts}
      ] ++
        for n <- [50, 200] do
          {"synthetic, #{n} rules", synthetic_rules(n), synthetic_facts(1000)}
        end

    IO.puts(
      "| corpus | reorder | beta nodes | tokens | memory (MB) | compile (ms) | assert (ms) | retract (ms) |"
    )

    IO.puts("|---|---|---:|---:|---:|---:|---:|---:|")

    for {name, rules, facts} <- corpora, reorder <- [false, true] do
      measure(name, rules, facts, reorder)
    end
  end

  defp measure(name, rules, facts, reorder) do
    results =
      for _ <- 1..@runs do
        {compile, rete} =
          :timer.tc(fn -> Engine.compile_all(Engine.new(), rules, reorder: reorder) end)

        {assert, full} = :timer.tc(fn -> Scenario.assert_all(rete, facts) end)
        {retract, _} = :timer.tc(fn -> Scenario.retract_all(full, facts) end)
        {compile, assert, retract, full}
      end

    {_, _, _, rete} = hd(results)
    tokens = rete.tokens |> Map.values() |> Enum.map(&MapSet.size/1) |> Enum.sum()
    memory = :erts_debug.size(rete) * :erlang.system_info(:wordsize) / 1_048_576

    IO.puts(
      "| #{name} | #{reorder} | #{map_size(rete.beta_table)} | #{tokens} | " <>
        "#{Float.round(memory, 1)} | #{median(results, 0)} | #{median(results, 1)} | #{median(results, 2)} |"
    )
  end

  defp median(results, field) do
    times = results |> Enum.map(&elem(&1, field)) |> Enum.sort()
    Float.round(Enum.at(times, div(length(times), 2)) / 1000, 1)
  end

  # A pool of patterns over a shared set of variables. Each rule grows a
  # connected subset of them in a random order, as a rule written by hand
  # would join each match with the ones before it.
  @vars 10
  @predicates 20

  defp pool do
    for p <- 1..@predicates do
      i = :rand.uniform(@vars) - 1
      j = rem(i + :rand.uniform(@vars - 1), @vars)
      has(var(:"v#{i}"), :"p#{p}", var(:"v#{j}"))
    end
  end

  defp synthetic_rules(n) do
    pool = pool()
    for _ <- 1..n, do: rule(forall: grow(pool, [Enum.random(pool)], Enum.random(3..6)))
  end

  defp grow(_pool, chosen, size) when length(chosen) == size, do: Enum.reverse(chosen)

  defp grow(pool, chosen, size) do
    bound = chosen |> Enum.flat_map(&vars/1) |> MapSet.new()

    case Enum.filter(pool -- chosen, &Enum.any?(vars(&1), fn v -> v in bound end)) do
      [] -> Enum.reverse(chosen)
      candidates -> grow(pool, [Enum.random(candidates) | chosen], size)
    end
  end

  defp vars(%{subject: s, object: o}), do: [s.name, o.name]

  defp synthetic_facts(n) do
    for _ <- 1..n do
      {:"e#{:rand.uniform(50)}", :"p#{:rand.uniform(@predicates)}", :"e#{:rand.uniform(50)}"}
    end
    |> Enum.uniq()
  end
end

Bench.RuleOrdering.run()
