defmodule Wongi.Engine.Compiler.Reorder do
  @moduledoc false
  # Reorders the clauses of a set of rules so that they share more beta nodes.
  #
  # Two rules share a node only if they share the whole chain of clauses that
  # leads to it, with the same variable names, so what matters is how long a
  # prefix they have in common. Positive matches are a conjunction and can be
  # put in any order; filters can be moved anywhere after the variables they
  # use are bound. Everything else (negations, NCCs, alternatives, assignments,
  # aggregates and opaque filters) stays where it is, and nothing moves across
  # it: such clauses divide a rule into segments, and only the clauses within
  # a segment are reordered.
  #
  # The rules are arranged into a trie greedily. Starting with all rules and an
  # empty prefix, the clause that the most rules can put next is put next in
  # all of them, and the rules that have it and those that do not are then
  # arranged separately. A clause can only go next if it binds no new
  # variables or joins with the ones already bound, unless the rule has no such
  # clause left, as a cross product costs more than sharing saves. Once a rule
  # has nothing left in common with any other, the rest of its clauses keep
  # their original order as far as they can while still joining with the ones
  # before them, so a rule that shares nothing is left as it is.
  #
  # Variables are not renamed, as their names are visible in the tokens, and
  # the subchains of NCCs and alternatives are not reordered.

  alias Wongi.Engine.DSL
  alias Wongi.Engine.DSL.Var
  alias Wongi.Engine.Filter

  @binary_filters [
    Filter.Diff,
    Filter.Equal,
    Filter.Greater,
    Filter.GTE,
    Filter.InList,
    Filter.Less,
    Filter.LTE,
    Filter.NotInList
  ]

  # A movable clause, with the variables of its segment that must be bound
  # before it and the ones it binds.
  defmodule Item do
    @moduledoc false
    @type t() :: %__MODULE__{
            clause: struct(),
            kind: :has | :filter,
            pos: non_neg_integer(),
            vars: MapSet.t(atom()),
            deps: MapSet.t(atom())
          }
    defstruct [:clause, :kind, :pos, :vars, :deps]
  end

  @spec reorder([DSL.Rule.t()]) :: [DSL.Rule.t()]
  def reorder(rules) do
    rules
    |> Enum.with_index(&new_state/2)
    |> arrange()
    |> Enum.sort_by(& &1.index)
    |> Enum.map(fn %{rule: %DSL.Rule{} = rule, forall: forall} -> %{rule | forall: forall} end)
  end

  defp new_state(rule, index) do
    %{
      index: index,
      rule: rule,
      emitted: [],
      bound: MapSet.new(),
      chunks: chunks(rule.forall)
    }
  end

  # The rest of the current segment keeps its original order as far as it
  # can, but the clauses put first may have left the next one in that order
  # with nothing to join with, so the first one that joins goes next instead.
  defp finished(%{chunks: [{:segment, _} | _]} = state) do
    [item | _] = candidates(state)
    state |> emit(item.clause) |> finished()
  end

  defp finished(%{emitted: emitted, chunks: chunks} = state) do
    rest =
      Enum.flat_map(chunks, fn
        {:barrier, clause} -> [clause]
        {:segment, items} -> Enum.map(items, & &1.clause)
      end)

    Map.put(state, :forall, Enum.reverse(emitted, rest))
  end

  # All the states given have the same prefix.
  defp arrange([]), do: []
  defp arrange([state]), do: [finished(state)]

  defp arrange(states) do
    {at_barrier, in_segment} = Enum.split_with(states, &at_barrier?/1)

    at_barrier
    |> Enum.group_by(&next_barrier/1)
    |> Enum.flat_map(fn
      {nil, done} -> Enum.map(done, &finished/1)
      {_, group} -> group |> Enum.map(&pass_barrier/1) |> arrange()
    end)
    |> Enum.concat(arrange_segment(in_segment))
  end

  defp at_barrier?(%{chunks: []}), do: true
  defp at_barrier?(%{chunks: [{:barrier, _} | _]}), do: true
  defp at_barrier?(_), do: false

  defp next_barrier(%{chunks: []}), do: nil
  defp next_barrier(%{chunks: [{:barrier, clause} | _]}), do: {:barrier, clause}

  defp pass_barrier(%{chunks: [{:barrier, clause} | rest]} = state) do
    %{
      state
      | emitted: [clause | state.emitted],
        bound: MapSet.union(state.bound, barrier_binds(clause)),
        chunks: rest
    }
  end

  defp arrange_segment([]), do: []
  defp arrange_segment([state]), do: [finished(state)]

  defp arrange_segment(states) do
    case best_candidate(states) do
      nil ->
        Enum.map(states, &finished/1)

      clause ->
        {with, without} = Enum.split_with(states, &(clause in candidate_clauses(&1)))
        arrange(Enum.map(with, &emit(&1, clause))) ++ arrange_segment(without)
    end
  end

  # The clauses that can go next, in their original order: those whose
  # dependencies are bound, and of them only those that join with the clauses
  # before them, unless none do and a cross product cannot be avoided. There
  # is always at least one, as the first clause in the original order has all
  # of its dependencies bound.
  defp candidates(%{chunks: [{:segment, items} | _], bound: bound}) do
    ready = items |> Enum.filter(&MapSet.subset?(&1.deps, bound)) |> Enum.uniq_by(& &1.clause)

    case Enum.filter(ready, &connected?(&1, bound)) do
      [] -> ready
      connected -> connected
    end
  end

  defp candidate_clauses(state), do: state |> candidates() |> Enum.map(& &1.clause)

  defp best_candidate(states) do
    items = Enum.flat_map(states, &candidates/1)
    counts = Enum.frequencies_by(items, & &1.clause)

    items
    |> Enum.uniq_by(& &1.clause)
    |> Enum.filter(&(counts[&1.clause] >= 2))
    |> Enum.min_by(&{-counts[&1.clause], &1.pos}, fn -> nil end)
    |> case do
      nil -> nil
      item -> item.clause
    end
  end

  defp connected?(%Item{kind: :filter}, _bound), do: true

  defp connected?(%Item{vars: vars}, bound) do
    MapSet.size(bound) == 0 or MapSet.size(vars) == 0 or not MapSet.disjoint?(vars, bound)
  end

  defp emit(%{chunks: [{:segment, items} | rest]} = state, clause) do
    {item, items} = pop_item(items, clause)
    chunks = if items == [], do: rest, else: [{:segment, items} | rest]

    %{
      state
      | emitted: [clause | state.emitted],
        bound: MapSet.union(state.bound, item.vars),
        chunks: chunks
    }
  end

  defp pop_item([%Item{clause: clause} = item | rest], clause), do: {item, rest}

  defp pop_item([item | rest], clause) do
    {found, rest} = pop_item(rest, clause)
    {found, [item | rest]}
  end

  # Splits a rule into segments of movable items and the barriers between
  # them. `bound` holds the variables bound so far in the rule, `local` the
  # ones first bound within the current segment, which are the only ones an
  # item can depend on.
  defp chunks(forall) do
    acc = %{chunks: [], segment: [], bound: MapSet.new(), local: MapSet.new()}

    forall
    |> Enum.with_index()
    |> Enum.reduce(acc, fn {clause, pos}, acc ->
      case item(clause, pos, acc) do
        nil -> barrier(acc, clause)
        item -> add_item(acc, item)
      end
    end)
    |> close_segment()
    |> Map.fetch!(:chunks)
    |> Enum.reverse()
  end

  defp add_item(acc, %Item{vars: vars} = item) do
    new = MapSet.difference(vars, acc.bound)

    %{
      acc
      | segment: [item | acc.segment],
        bound: MapSet.union(acc.bound, vars),
        local: MapSet.union(acc.local, new)
    }
  end

  defp barrier(acc, clause) do
    acc = close_segment(acc)

    %{
      acc
      | chunks: [{:barrier, clause} | acc.chunks],
        bound: MapSet.union(acc.bound, barrier_binds(clause)),
        local: MapSet.new()
    }
  end

  defp close_segment(%{segment: []} = acc), do: acc

  defp close_segment(acc) do
    %{acc | chunks: [{:segment, Enum.reverse(acc.segment)} | acc.chunks], segment: []}
  end

  defp item(%DSL.Has{} = clause, pos, acc) do
    vars = has_vars(clause)

    # vars is not passed to MapSet.union/2 or MapSet.difference/2, which make
    # dialyzer lose track of it being opaque
    with {:ok, used} <- filter_vars(clause.filters),
         true <- Enum.all?(used, &(MapSet.member?(acc.bound, &1) or MapSet.member?(vars, &1))) do
      deps = used |> MapSet.intersection(acc.local) |> MapSet.reject(&MapSet.member?(vars, &1))
      %Item{clause: clause, kind: :has, pos: pos, vars: vars, deps: deps}
    else
      _ -> nil
    end
  end

  # A filter that uses a variable which is not bound yet would see it bound if
  # it were moved after the clause that binds it, so it stays where it is.
  defp item(%DSL.Filter{filter: filter} = clause, pos, acc) do
    with {:ok, used} <- filter_vars(filter),
         true <- MapSet.subset?(used, acc.bound) do
      deps = MapSet.intersection(used, acc.local)
      %Item{clause: clause, kind: :filter, pos: pos, vars: MapSet.new(), deps: deps}
    else
      _ -> nil
    end
  end

  defp item(_clause, _pos, _acc), do: nil

  defp has_vars(%DSL.Has{subject: s, predicate: p, object: o}) do
    MapSet.new(for %Var{name: name} <- [s, p, o], do: name)
  end

  defp barrier_binds(%DSL.Assign{name: name}), do: MapSet.new([name])
  defp barrier_binds(%DSL.Aggregate{var: var}), do: MapSet.new([var])
  defp barrier_binds(_), do: MapSet.new()

  defp filter_vars(nil), do: {:ok, MapSet.new()}

  defp filter_vars(filters) when is_list(filters) do
    Enum.reduce_while(filters, {:ok, MapSet.new()}, fn filter, {:ok, acc} ->
      case filter_vars(filter) do
        {:ok, vars} -> {:cont, {:ok, MapSet.union(acc, vars)}}
        :opaque -> {:halt, :opaque}
      end
    end)
  end

  defp filter_vars(%DSL.Filter{filter: filter}), do: filter_vars(filter)
  defp filter_vars(%Filter.Function{var: %Var{name: name}}), do: {:ok, MapSet.new([name])}

  defp filter_vars(%module{a: a, b: b}) when module in @binary_filters do
    {:ok, MapSet.new(for %Var{name: name} <- [a, b], do: name)}
  end

  defp filter_vars(_), do: :opaque
end
