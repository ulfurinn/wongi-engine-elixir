# Rule reordering

`Wongi.Engine.compile_all/3` compiles a collection of rules. With
`reorder: true`, it first reorders the clauses of each rule so that the rules
share more beta nodes. This document describes how that works, why it is
correct, and what it buys. The implementation is in
`lib/wongi/engine/compiler/reorder.ex` (`Wongi.Engine.Compiler.Reorder`).

Reordering is opt-in. Without it, `compile_all/3` is a fold over
`compile/2`.

## Why clause order matters for sharing

While compiling a clause, `Compiler.find_existing/2` reuses an existing child
of the current node if it is `Beta.equivalent?` to the node it would create.
For a join, that means the same parent, template, tests, assignments and
`when:` filters. A filter node is equivalent when its filter struct is `==`.

Two consequences:

- Rules share a node only if they share the whole chain of clauses leading to
  it. Sharing is by prefix, so `[a, b, c]` and `[b, a]` share nothing, but
  `[a, b, c]` and `[a, b]` share two joins.
- Tests and assignments are keyed by variable name, and whether a variable is
  a test or an assignment depends on the clauses before it. Prefixes match
  only when they use the same variable names.

The order in which rules are compiled does not affect sharing; only the order
of clauses within each rule does.

## What may move

A rule's `forall` is split into **segments** of movable clauses, separated by
**barriers**. Clauses are only reordered within a segment, and nothing moves
across a barrier.

Movable clauses:

- `has` (`DSL.Has`). Joins are a conjunction, so any order of a run of them
  produces the same bindings.
- `DSL.Filter` whose variables can be read from the struct: `Diff`, `Equal`,
  `Greater`, `GTE`, `InList`, `Less`, `LTE`, `NotInList` (fields `a`/`b`), and
  `Function` with a `var` (`filter/2`).

Barriers:

- `neg`, `ncc`, `any`, `assign`, `aggregate`.
- `filter/1` (an opaque function of the token) and any filter struct not
  listed above.
- A `has` whose `when:` filters are opaque, or use a variable that is bound
  neither before it nor by the `has` itself.
- A filter that uses a variable not bound before it in the original order.
  Such a filter sees that variable as `nil`, and moving it after the clause
  that binds the variable would change its result.

Barriers keep their position because moving clauses across them changes
meaning. A `neg` decides between tests and local variables based on what is
bound before it, an aggregate partitions the tokens above it, and an opaque
function may read anything.

Each movable clause becomes an `Item` with:

- `vars`: the variables it binds or tests. This is empty for filters.
- `deps`: the variables that must be bound before it can go, limited to those
  first bound **within the same segment**. Variables bound by earlier segments
  or barriers are always bound by the time the segment starts, so they never
  constrain the order. For a `has`, `deps` are the variables of its `when:`
  filters other than its own.

## The algorithm

The rules are arranged into a trie greedily. A **state** tracks one rule: the
clauses emitted so far, the variables bound so far, and the remaining chunks
(segments and barriers). `arrange/1` takes a group of states that all have the
same emitted prefix, and therefore the same bound variables.

1. States whose next chunk is a barrier, or that are finished, are grouped by
   that barrier. Each group passes it and is arranged further.
2. For the remaining states, `candidates/1` gives the items that can go next:
   those whose `deps` are bound. Of these, only items that are **connected**
   count. A connected item is a filter, a `has` with no variables, a `has`
   that shares a variable with the bound set, or any item when nothing is
   bound yet. If a state has no connected item, all of its ready items count:
   the cross product is unavoidable for that rule, and it can still be shared.
3. `best_candidate/1` picks the candidate that the most states have, if at
   least two have it. Ties go to the earliest position in the original order
   of the first rule in the group that has it.
4. The states that have it emit it and are arranged further. The states that
   do not have it are arranged again from step 2, with the same prefix.
5. When no candidate is shared, each state is finished on its own.
   `finished/1` emits the rest of the current segment, each time taking the
   first candidate in the original order. Later chunks stay as written.

### Why connectivity is required

An earlier version only *preferred* connected candidates. If the most shared
candidate didn't join with the bound variables, it was hoisted anyway, and so
were the remaining clauses in their original order after a shared prefix.
Both produced cross products. In the synthetic benchmark, a few nodes grew to
about 13,000 tokens, the total token count went up 4× and retraction slowed
down 6×. A shared cross product is still far more expensive than two unshared
joins, so connectivity is a hard rule unless the rule has no connected option.

### Correctness

- **Bindings are the same.** Within a segment, every permutation of the `has`
  clauses binds the same variables to the same values. Filters only go once
  their `deps` are bound, and a filter that could see a different binding
  after moving is a barrier. Barriers see the same bound set as before,
  because segments only permute their own contents.
- **Every step can go.** The first remaining item in the original order
  always has its `deps` bound: everything before it in the original order has
  already been emitted, since items only ever move earlier. So `candidates/1`
  is never empty for a state inside a segment.
- **Rules that share nothing are unchanged**, as long as their original order
  is connected. `finished/1` then reproduces that order.
- **Rule identity is kept.** Only `forall` is replaced, so `ref`, `name` and
  `actions` stay the same.

Token contents differ from the unordered rule (the WMEs are joined in a
different order), but `Token.assignments/1` and generated facts do not.

## Limitations

- Variables are not renamed (alpha-equivalence). Rules that use different
  names for the same thing will not share, because names are visible to users
  in tokens.
- The subchains of `ncc` and `any` are not reordered.
- The connectivity check only tracks variables bound by `has`, `assign` and
  `aggregate`. Variables bound inside an `any` are not tracked, so a `has`
  after an `any` may wrongly count as unconnected. This loses sharing but
  never correctness.
- The ordering ignores selectivity. Hoisting the most widely shared clause
  can put a weak join ahead of a selective one, which is why reordering is
  not the default.
- Reordering is greedy, so it finds a good arrangement, not necessarily the
  one with the most sharing. In the benchmark, it adds a few milliseconds per
  few hundred rules to compilation.

## Tests

- `test/wongi/engine/compiler/reorder_test.exs`: unit cases for shared
  prefixes, unchanged rules, filter and `when:` dependencies, barriers,
  connectivity (including the shared unavoidable cross product and the
  connected tail), beta node counts, and matching the same tokens.
- `test/wongi/scenarios/consistency_test.exs`, property *"reordered rules
  agree with rules compiled as written"*: for every scenario, the rules have
  each run of plain `has` clauses shuffled (`Scenario.shuffle_matches/1`). The
  shuffled rules are compiled both as written and reordered, put through the
  same random sequence of assertions and retractions, and compared with
  `Scenario.observe/2` after every step.

## Benchmark

```
MIX_ENV=test mix run bench/rule_ordering.exs
```

The script runs under `MIX_ENV=test` because the scenarios live in
`test/support`. It compares `reorder: false` and `reorder: true` on three
corpora:

- the four scenarios as written;
- the same scenarios with their matches shuffled;
- synthetic rule sets of 50 and 200 rules. Each rule grows a connected subset
  of 3–6 clauses from a pool of 20 patterns over 10 shared variables, in
  random order. The workload is 1000 random facts.

Each case takes the median of 3 runs. The script takes about 2 minutes.
Results from one run:

| corpus | reorder | beta nodes | tokens | memory (MB) | compile (ms) | assert (ms) | retract (ms) |
|---|---|---:|---:|---:|---:|---:|---:|
| scenarios | false | 280 | 7264 | 2.4 | 0.4 | 33.2 | 251.1 |
| scenarios | true | 270 | 7564 | 2.4 | 1.5 | 33.8 | 258.3 |
| scenarios, shuffled | false | 281 | 8288 | 2.6 | 0.4 | 35.4 | 283.5 |
| scenarios, shuffled | true | 270 | 7796 | 2.5 | 1.4 | 30.8 | 258.0 |
| synthetic, 50 rules | false | 229 | 7482 | 2.4 | 0.3 | 31.0 | 17.5 |
| synthetic, 50 rules | true | 176 | 6069 | 2.0 | 0.8 | 22.6 | 13.6 |
| synthetic, 200 rules | false | 796 | 30560 | 8.0 | 1.1 | 123.0 | 73.3 |
| synthetic, 200 rules | true | 590 | 22762 | 6.0 | 3.7 | 72.4 | 51.2 |

The scenario facts come from StreamData and differ between runs. Compare
`false` and `true` within a run, not across runs.

How to read it:

- With many rules over a shared vocabulary written in different orders,
  reordering cuts beta nodes and tokens by about a quarter, assertion time by
  up to 40% and retraction time by about 30%.
- Hand-written rules that share little gain nothing, and may store slightly
  more tokens when a shared clause is less selective than the one it
  displaces.
- Compilation is 3–4× slower, which is negligible next to working-memory
  operations.

## Possible follow-ups

- Factor selectivity into `best_candidate/1`, for example by preferring
  clauses with literals in the template, or by using alpha memory sizes when
  compiling into a populated engine.
- Rename variables to canonical names internally, and map them back in
  `Token.assignments/1`, so that rules can share regardless of naming.
- Retraction cost grows with node size independently of this feature.
  `Beta.Common.beta_deactivate/3` scans all tokens of each child node for
  every removed token or WME. Indexing tokens by parent or by WME would help
  every rule set, reordered or not.
