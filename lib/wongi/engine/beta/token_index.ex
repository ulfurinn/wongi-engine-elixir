defmodule Wongi.Engine.Beta.TokenIndex do
  @moduledoc false
  # Keys for Rete's per-node join token index. A node that tests WME fields
  # against token variables stores its input tokens under the values of those
  # variables, so that an alpha activation can fetch only the tokens that can
  # possibly match instead of scanning all of them.
  alias Wongi.Engine.Rete
  alias Wongi.Engine.Token

  @tested_fields [:subject, :predicate, :object]

  # A token that does not (yet) bind one of the tested variables, e.g. because
  # the variable is introduced by the same clause, goes to :unindexed and is
  # always considered.
  def token_key(tests, token) do
    @tested_fields
    |> Enum.filter(&Map.has_key?(tests, &1))
    |> Enum.reduce_while([], fn field, acc ->
      case Token.fetch(token, Map.fetch!(tests, field)) do
        {:ok, value} -> {:cont, [value | acc]}
        :error -> {:halt, :unindexed}
      end
    end)
    |> case do
      :unindexed -> :unindexed
      values -> Enum.reverse(values)
    end
  end

  def wme_key(tests, wme) do
    for field <- @tested_fields, Map.has_key?(tests, field), do: wme[field]
  end

  def put(rete, %{ref: ref, tests: tests}, token),
    do: Rete.index_join_token(rete, ref, token_key(tests, token), token)

  def delete(rete, %{ref: ref, tests: tests}, token),
    do: Rete.unindex_join_token(rete, ref, token_key(tests, token), token)

  def candidates(rete, %{ref: ref, tests: tests}, wme) do
    rete
    |> Rete.join_tokens(ref, wme_key(tests, wme))
    |> Enum.concat(Rete.join_tokens(rete, ref, :unindexed))
  end
end
