defmodule Wongi.Engine.Compiler do
  @moduledoc false
  alias Wongi.Engine.Beta
  alias Wongi.Engine.Beta.Production
  alias Wongi.Engine.DSL.Clause
  alias Wongi.Engine.DSL.Rule
  alias Wongi.Engine.Rete

  defstruct [:rete, :node_ref, :variables]

  def compile(rete, %Rule{} = rule) do
    context = %__MODULE__{
      rete: rete,
      node_ref: Beta.ref(rete.beta_root),
      variables: MapSet.new()
    }

    context =
      Enum.reduce(rule.forall, context, &Clause.compile/2)
      |> production(rule.ref, rule.actions)

    context.rete
  end

  def find_existing(%__MODULE__{rete: rete, node_ref: node_ref} = _context, node) do
    rete
    |> Rete.beta_subscriptions(node_ref)
    |> Enum.find(&Beta.equivalent?(&1, node, rete))
  end

  def declare_variable(%__MODULE__{variables: variables} = context, var) do
    %__MODULE__{context | variables: MapSet.put(variables, var)}
  end

  def advance(%__MODULE__{rete: rete} = context, node) do
    parent_refs = Beta.parent_refs(node)

    rete =
      parent_refs
      |> Enum.reduce(rete, &Beta.seed(&1, node, &2))
      |> Rete.add_beta(node)

    context
    |> put_node(node)
    |> put_rete(rete)
  end

  def advance_existing(%__MODULE__{} = context, node) do
    context
    |> put_node(node)
  end

  def put_rete(context, rete) do
    %__MODULE__{context | rete: rete}
  end

  defp put_node(%__MODULE__{} = context, node) do
    %__MODULE__{context | node_ref: Beta.ref(node)}
  end

  defp production(context, ref, actions) do
    node = Production.new(ref, context.node_ref, actions)

    case find_existing(context, node) do
      nil ->
        context
        |> advance(node)

      node ->
        context
        |> advance_existing(node)
    end
  end
end
