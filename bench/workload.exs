# Usage: mix run bench/workload.exs [n] [--profile [phase]] [--runs k] [--json file]
# Dependency-free benchmark; prints wall time per phase.
# With --profile, runs :eprof over the assert phase, or the one given.
# With --runs, repeats the workload k times and reports the median of each phase.
# With --json, also writes the timings to a file.
use Wongi.Engine.DSL

{options, argv} =
  Enum.reduce([runs: "--runs", json: "--json"], {%{}, System.argv()}, fn {key, flag}, {options, argv} ->
    case Enum.split_while(argv, &(&1 != flag)) do
      {before, [^flag, value | rest]} -> {Map.put(options, key, value), before ++ rest}
      _ -> {options, argv}
    end
  end)

{n, profile?, phase} =
  case argv do
    ["--profile"] -> {200, true, "assert"}
    [n, "--profile"] -> {String.to_integer(n), true, "assert"}
    [n, "--profile", phase] -> {String.to_integer(n), true, phase}
    [n] -> {String.to_integer(n), false, nil}
    _ -> {200, false, nil}
  end

runs = String.to_integer(Map.get(options, :runs, "1"))

profiled = fn label, fun ->
  if profile? and label == phase do
    Mix.ensure_application!(:tools)
    :eprof.start()
    :eprof.start_profiling([self()])
    result = fun.()
    :eprof.stop_profiling()
    :eprof.analyze(:total, sort: :time)
    {nil, result}
  else
    :timer.tc(fun)
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

workload = fn ->
  {assert_us, loaded} = profiled.("assert", assert_all)

  {bans_us, _} =
    profiled.("retract bans", fn ->
      Enum.reduce(0..div(n, 2), loaded, fn i, r -> Wongi.Engine.assert(r, i, :banned, true) end)
    end)

  {retract_us, _} =
    profiled.("retract", fn ->
      Enum.reduce(0..(n - 1), loaded, fn i, r ->
        Enum.reduce(facts.(i), r, fn {s, p, o}, r -> Wongi.Engine.retract(r, s, p, o) end)
      end)
    end)

  [{"assert", assert_us}, {"retract bans", bans_us}, {"retract", retract_us}]
end

median = fn values ->
  sorted = Enum.sort(values)
  Enum.at(sorted, div(length(sorted), 2))
end

phases =
  1..runs
  |> Enum.map(fn _ -> workload.() end)
  |> Enum.zip_with(fn [{label, _} | _] = timings ->
    {label, timings |> Enum.map(&elem(&1, 1)) |> Enum.reject(&is_nil/1)}
  end)
  |> Enum.reject(fn {_label, us} -> us == [] end)
  |> Enum.map(fn {label, us} -> {label, div(median.(us), 1000)} end)

for {label, ms} <- phases, do: IO.puts("#{String.pad_trailing(label, 12)} #{ms} ms")

if path = options[:json] do
  report = %{
    commit: System.get_env("GITHUB_SHA"),
    n: n,
    runs: runs,
    elixir: System.version(),
    otp: System.otp_release(),
    phases_ms: Map.new(phases)
  }

  File.write!(path, JSON.encode!(report))
end
