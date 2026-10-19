# Usage: mix run bench/workload.exs [n] [--profile]
# Dependency-free benchmark; prints wall time per phase.
# With --profile, runs :eprof over the assert phase.
use Wongi.Engine.DSL

{n, profile?, phase} =
  case System.argv() do
    ["--profile"] -> {200, true, "assert"}
    [n, "--profile"] -> {String.to_integer(n), true, "assert"}
    [n, "--profile", phase] -> {String.to_integer(n), true, phase}
    [n] -> {String.to_integer(n), false, nil}
    _ -> {200, false, nil}
  end

profiled = fn label, fun ->
  if profile? and label == phase do
    Mix.ensure_application!(:tools)
    :eprof.start()
    :eprof.start_profiling([self()])
    result = fun.()
    :eprof.stop_profiling()
    :eprof.analyze(:total, sort: :time)
    result
  else
    {us, result} = :timer.tc(fun)
    IO.puts("#{String.pad_trailing(label, 12)} #{div(us, 1000)} ms")
    result
  end
end

rete =
  Wongi.Engine.new()
  |> Wongi.Engine.compile(
    rule(:join, forall: [has(var(:p), :parent, var(:c)), has(var(:c), :age, var(:a)), has(var(:p), :name, var(:n))])
  )
  |> Wongi.Engine.compile(
    rule(:neg, forall: [has(var(:x), :kind, :person), neg(var(:x), :banned, any())])
  )
  |> Wongi.Engine.compile(
    rule(:ncc, forall: [has(var(:x), :kind, :person), ncc([has(var(:x), :friend, var(:y)), has(var(:y), :banned, any())])])
  )

facts = fn i ->
  [
    {i, :kind, :person},
    {i, :name, "n#{i}"},
    {i, :age, rem(i, 90)},
    {i, :parent, rem(i * 7, n)},
    {i, :friend, rem(i * 13, n)}
  ]
end

assert_all = fn ->
  Enum.reduce(0..(n - 1), rete, fn i, r ->
    Enum.reduce(facts.(i), r, fn {s, p, o}, r -> Wongi.Engine.assert(r, s, p, o) end)
  end)
end

loaded = profiled.("assert", assert_all)

profiled.("retract bans", fn ->
  Enum.reduce(0..div(n, 2), loaded, fn i, r -> Wongi.Engine.assert(r, i, :banned, true) end)
end)

profiled.("retract", fn ->
  Enum.reduce(0..(n - 1), loaded, fn i, r ->
    Enum.reduce(facts.(i), r, fn {s, p, o}, r -> Wongi.Engine.retract(r, s, p, o) end)
  end)
end)
