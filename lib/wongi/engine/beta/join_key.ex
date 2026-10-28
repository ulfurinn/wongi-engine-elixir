defmodule Wongi.Engine.Beta.JoinKey do
  @moduledoc false
  # Index keys for nodes that test WME fields against token variables (join and
  # negation). Such a node stores its input tokens in Rete's node index under
  # the values of the variables it tests, so that an alpha activation can fetch
  # only the tokens that can possibly match instead of scanning all of them.
  #
  # Only variables that the token is expected to carry take part in the key.
  # Variables introduced by the same clause that also tests them, as in
  # `has(x, :friend, x)`, are supplied by the WME during matching and are never
  # in the token, so they are left out. A node left with nothing to index on
  # indexes no tokens at all.
  #
  # The fields depend only on the node's tests and assignments, so nodes compute
  # them once with index_fields/2 when they are built.
  alias Wongi.Engine.Rete
  alias Wongi.Engine.Token

  @fields [:subject, :predicate, :object]

  # A token is not indexed when there is nothing to index on, or when it does
  # not bind a variable that the node tests; such a token cannot match any WME
  # anyway.
  def index_keys(node, token) do
    case token_key(node, token) do
      nil -> []
      key -> [key]
    end
  end

  defp token_key(%{index_fields: index_fields}, token) do
    case index_fields do
      [] -> nil
      fields -> fields |> Enum.map(fn {_field, var} -> Token.fetch(token, var) end) |> values()
    end
  end

  defp values(fetched) do
    if Enum.all?(fetched, &match?({:ok, _}, &1)), do: Enum.map(fetched, &elem(&1, 1))
  end

  def wme_key(%{index_fields: index_fields}, wme) do
    case index_fields do
      [] -> nil
      fields -> for {field, _var} <- fields, do: wme[field]
    end
  end

  # The tokens that may match the WME.
  def candidates(rete, node, wme) do
    case wme_key(node, wme) do
      nil -> Rete.tokens(rete, node)
      key -> Rete.get_node_index(rete, node, key)
    end
  end

  def index_fields(tests, assignments) do
    local_vars = Map.values(assignments)

    for field <- @fields,
        {:ok, var} <- [Map.fetch(tests, field)],
        var not in local_vars,
        do: {field, var}
  end
end
