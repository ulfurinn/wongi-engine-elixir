defmodule Wongi.Engine.Beta.Or do
  @moduledoc false
  @type t() :: %__MODULE__{}
  defstruct [:ref, :parent_refs]

  def new(parent_refs) do
    %__MODULE__{
      ref: make_ref(),
      parent_refs: MapSet.new(parent_refs)
    }
  end

  defimpl Wongi.Engine.Beta do
    alias Wongi.Engine.Beta.Common
    alias Wongi.Engine.Rete
    alias Wongi.Engine.Token

    def ref(%@for{ref: ref}), do: ref
    def parent_refs(%@for{parent_refs: parent_refs}), do: parent_refs

    def seed(node, beta, rete) do
      tokens = Rete.tokens(rete, node)

      Enum.reduce(tokens, rete, fn token, rete ->
        Common.beta_activate([beta], &Token.new(&1, [token], nil), rete)
      end)
    end

    def equivalent?(%@for{parent_refs: parent_refs}, %@for{parent_refs: parent_refs}, _rete),
      do: true

    def equivalent?(_, _, _), do: false

    @spec alpha_activate(
            Wongi.Engine.Beta.Or.t(),
            Wongi.Engine.WME.t(),
            Wongi.Engine.Rete.t()
          ) :: no_return()
    defdelegate alpha_activate(node, alpha, rete), to: Wongi.Engine.Beta.NonAlphaListening

    @spec alpha_deactivate(
            Wongi.Engine.Beta.Or.t(),
            Wongi.Engine.WME.t(),
            Wongi.Engine.Rete.t()
          ) :: no_return()
    defdelegate alpha_deactivate(node, alpha, rete), to: Wongi.Engine.Beta.NonAlphaListening

    def beta_activate(node, token, rete) do
      rete = Rete.add_token(rete, token)
      betas = Rete.beta_subscriptions(rete, node)
      Common.beta_activate(betas, &Token.new(&1, [token], nil), rete)
    end

    def beta_deactivate(node, token, rete) do
      rete =
        rete
        |> Rete.remove_token(token)

      rete
      |> Rete.beta_subscriptions(node)
      |> Common.beta_deactivate(token, rete)
    end
  end
end
