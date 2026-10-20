# Token indexing

Notes on the secondary indexes added in the `secondary-index` branch: what problem they solve, what the indexes are, who maintains them, and where the invariants are fragile.

## Problem

`Rete.tokens` is a `%{node_ref => MapSet.t(Token)}`: every token a node holds, unordered. Several hot paths needed "the tokens of node N that relate to X" and answered it by scanning all of N's tokens:

| Path | Question | Old cost per operation |
|---|---|---|
| `Join.alpha_activate`, `Negative.alpha_activate` | which input tokens can match this new WME? | all input tokens, each with an ancestry walk and a `match` |
| `Common.beta_deactivate` (token) | which child tokens have this parent? | all of the child's tokens |
| `Common.beta_deactivate` (WME) | which child tokens hold this WME? | all of the child's tokens |
| `NCC.beta_activate` / `Partner.owner_for` | which partner tokens belong to this owner (and vice versa)? | all tokens, with a lineage walk |
| `Aggregate.evaluate_changed_partition` | which tokens are in this partition? | `group_by` over all tokens |
| `Aggregate.evaluate_partition` | which child tokens derive from this group? | all of the child's tokens |

N facts therefore cost O(N) per assertion, O(N²) overall. (`beta_activate` on a join was already fast: it specialises the template and uses the alpha index.) Profile before and after: `bench/workload.exs`.

## The indexes

Both live in `Wongi.Engine.Rete` and are only ever touched through the functions below.

### 1. Generic, maintained by `Rete.add_token` / `remove_token`

Applies to every node, automatically.

- `tokens_by_parent: %{{node_ref, parent_token.ref} => MapSet.t(Token)}`: a token is stored once under each of its parents.
- `tokens_by_wme: %{{node_ref, wme} => MapSet.t(Token)}`: a token is stored under its own WME, if it has one.

Read with `Rete.child_tokens(rete, node, parent_token)` and `Rete.tokens_with_wme(rete, node, wme)`. These replace the filters in `Common.beta_deactivate`, and the child scan in `Aggregate.evaluate_partition`.

Keying on `parent.ref` rather than the parent struct avoids hashing a deeply nested term on every operation. This is safe because tokens are never modified after creation, so equal ref implies equal token.

### 2. Node-specific, `node_index`, maintained by the node

`node_index: %{node_ref => %{key => MapSet.t(Token)}}`, with the API

```elixir
Rete.put_node_index(rete, node, key, token)
Rete.delete_node_index(rete, node, key, token)
Rete.get_node_index(rete, node, key)        # empty MapSet if none
```

This is the one function set every node uses. It is deliberately a dumb two-level multimap; what the *key* means is up to the node. A `nil` key means "not indexed" and makes put and delete no-ops, so a key function can decline to index a token. Because the node supplies the key, the node must also call put and delete itself (see "Invariants").

| Node | key | looked up by |
|---|---|---|
| Join, Negative | values of the variables the node tests against tokens, in `subject, predicate, object` order (`JoinKey`) | `alpha_activate` |
| NCC | `Token.signature(token)` | partner's `beta_activate` |
| NCC partner | signature of **every token in the token's lineage** | `NCC.beta_activate` (via `owner_for`) |
| Aggregate | partition value (only when partitioned and non-nil) | `evaluate_changed_partition` |

## Join and Negative keys

Implemented in [join_key.ex](../lib/wongi/engine/beta/join_key.ex).

A join clause like `has(var(:p), :parent, var(:c))` has a `tests` map, here `%{subject: :p}`, saying which WME fields must equal which token variables. So:

- **Token key** (on `beta_activate`): `token_key(node, token)` is the list of `Token.fetch(token, var)` for each indexed field, in fixed field order.
- **WME key** (on `alpha_activate`): `wme_key(node, wme)` is the list of `wme[field]` for the same fields.
- A WME can only match tokens stored under exactly its key, so `candidates/3` fetches that one bucket. Matching is by exact term equality, the same as the `{:ok, ^value}` pin in `match/3`.

Which fields are indexed (`index_fields/1`): the tested fields, **except** those whose variable is introduced by the same clause (it is in the node's `assignments`). Such a variable is supplied by the WME during `match/3` and is never in the input token. This happens for a variable repeated within its first clause: `has(x, :friend, x)`, or `neg(x, y, y)` where `y` is new. There the second occurrence is a test, but the token can't hold the value.

When no fields are left to index, the key is `nil`: nothing is indexed, and `candidates/3` falls back to all of the node's tokens (`Rete.tokens`). That is the common case for the first clause after the root, and in effect it is the old behaviour, minus a redundant copy of every token.

A token that doesn't bind a variable that the node does test gets a `nil` key too. It can never match: `match/3` would fail on `Token.fetch`. So it needn't be a candidate, though it is still in `Rete.tokens`.

Two properties to keep in mind:

- **`candidates` only narrows.** `match/3` still runs on the survivors, so the index has to be a superset of the true matches, never exact.
- **Join still skips tokens that already contain the WME** (`Token.ancestral_wme?`). That's needed, not redundant: alpha activations of a WME run in the order of the alpha patterns (`@alpha_patterns` in `Rete`), not the order of clauses. When the parent clause's pattern runs first, the child sees a token that already contains this very WME and would combine it with itself. The regression tests are in `generate_test.exs`. `Negative` doesn't need the check because recording a join result twice is idempotent, so it was removed there.

## NCC signatures

`Token.signature/1` is `{wme, assignments, parent_refs}`, which is exactly what `Token.duplicate?/2` compared. `Token.lineage_of?(ncc_token, owner)` is true when `ncc_token` or any ancestor is a duplicate of `owner`. So:

- NCC node tokens are indexed under their own signature.
- Partner tokens are indexed under the signature of each token in their lineage (`Token.lineage_signatures/1`).
- **Partner token arrives:** for each lineage signature, look up the NCC node's bucket. That yields the candidate owners, still verified with `owner_token?`.
- **NCC token arrives:** look up the partner's bucket under its own signature. That yields the partner tokens it owns, again verified.

## Aggregate

Partitioned aggregates store each input token under `partition.(token)`. A change then re-aggregates only that bucket. When there is no partition, or the partition value is `nil`/`false`, it uses all of `Rete.tokens` as before. That `if token_partition` quirk was already there and is preserved, and those tokens are not indexed.

The aggregated child token also now carries its group's merged assignments in its own `assignments`, merged in sorted order, so which parent's binding wins is deterministic. This is separate from the indexing but lives in the same change set.

## Invariants (where it can break)

1. **Index and `tokens` are updated together.** The generic indexes are handled inside `add_token` / `remove_token`. The `node_index` ones are not: each node that uses them calls put in its `beta_activate` and delete in its `beta_deactivate`, next to `add_token`/`remove_token`. Any new code path that adds or removes tokens of such a node without doing so leaves a stale index. Nodes: Join, Negative, NCC, NCC partner, Aggregate.
2. **Key must be computed identically on put and delete.** It is derived from the token (and node), which is immutable, so it is stable. If tokens ever became mutable, this breaks.
3. **Indexes must be supersets of the matches.** The consumers re-check, so extra candidates are harmless; missing ones are not. A token may only be left out of `node_index` (nil key) if it can't match anything.
4. **No registration step.** The node computes keys itself from its own `tests`, so it doesn't matter that the parent seeds a new node before it is added to `beta_table` (the order in `Compiler.advance`).
5. **Iteration order is not guaranteed** between the old and new code, since lookups return per-bucket MapSets. Anything order-sensitive downstream is affected; I only found the aggregate assignment merge, which is now sorted.

## Verification

- The existing test suite.
- Randomized differential runs against the pre-change code: 400 random assert/retract operations over rules covering join, `neg`, `ncc`, a self-join, `neg` after `has`, and aggregates (partitioned, unpartitioned, with a following join, after a `neg`). Token assignments compared after every step. The scripts were throwaway and are not in the repo; recreating them is a good first step if you change this area.
- `bench/workload.exs [n] [--profile [assert|"retract bans"|retract]]`. At n = 2000 on the author's machine, assert went from 1.8 s to ~0.2 s, retract from 1.0 s to ~0.12 s, and the negation/NCC retract phase from 1.85 s to ~0.03 s.

## Known remaining scans

- `Or`, `Filter`, `Assign`: `seed` iterates every token, which is required when a rule is compiled.
- Unpartitioned `Aggregate`: re-runs the aggregate function over all tokens on every change, inherent to the aggregation.

## Ideas not done

- Make un-bound conflicting variables after an aggregate really unbound rather than "greatest wins".
- Merge the `node_index` put/delete calls into the generic `add_token`/`remove_token` by giving nodes a protocol callback that returns their key, which would remove invariant 1 at the cost of a bigger change.
- Key the remaining MapSets that hold whole tokens (`tokens`, the buckets above, `generation_by_*`, `neg_join_results`, `ncc_tokens`) by `token.ref`. Hashing a whole token is only about 1-2 µs more than hashing a ref for ordinary tokens, but it grows with the size of the token: an aggregated token with 1000 parents costs about 500 µs per set operation, against well under 1 µs by ref.
