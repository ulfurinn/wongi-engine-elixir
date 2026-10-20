defmodule Wongi.Engine.Beta.NCC.Partner do
  @moduledoc false
  alias Wongi.Engine.Rete
  alias Wongi.Engine.Token

  @type t() :: %__MODULE__{}
  defstruct [:ref, :parent_ref, :ncc_ref]

  def owner_for(%__MODULE__{ncc_ref: ncc}, ncc_token, rete) do
    ncc_token
    |> Token.lineage_signatures()
    |> Enum.flat_map(&Enum.to_list(Rete.get_node_index(rete, ncc, &1)))
    |> Enum.find(&owner_token?(&1, ncc_token))
  end

  # Partner tokens are indexed under the signature of each token in their
  # lineage, so that an NCC node can find the partner tokens it owns.
  def index(rete, %__MODULE__{} = node, token) do
    token
    |> Token.lineage_signatures()
    |> Enum.reduce(rete, &Rete.put_node_index(&2, node, &1, token))
  end

  def unindex(rete, %__MODULE__{} = node, token) do
    token
    |> Token.lineage_signatures()
    |> Enum.reduce(rete, &Rete.delete_node_index(&2, node, &1, token))
  end

  def owner_token?(token, ncc_token) do
    Token.lineage_of?(ncc_token, token)
  end

  defimpl Wongi.Engine.Beta do
    alias Wongi.Engine.Beta.NCC
    alias Wongi.Engine.Rete

    def ref(%@for{ref: ref}), do: ref
    def parent_refs(%@for{parent_ref: parent_ref}), do: [parent_ref]

    @spec seed(
            Wongi.Engine.Beta.NCC.Partner.t(),
            Wongi.Engine.Beta.t(),
            Wongi.Engine.Rete.t()
          ) :: no_return()
    def seed(_, _, _), do: raise("NCC partner nodes may not have children")

    # equivalence is a bit to think about weird for NCC
    def equivalent?(_, _, _), do: false

    @spec alpha_activate(
            Wongi.Engine.Beta.NCC.Partner.t(),
            Wongi.Engine.WME.t(),
            Wongi.Engine.Rete.t()
          ) :: no_return()
    defdelegate alpha_activate(node, alpha, rete), to: Wongi.Engine.Beta.NonAlphaListening

    @spec alpha_deactivate(
            Wongi.Engine.Beta.NCC.Partner.t(),
            Wongi.Engine.WME.t(),
            Wongi.Engine.Rete.t()
          ) :: no_return()
    defdelegate alpha_deactivate(node, alpha, rete), to: Wongi.Engine.Beta.NonAlphaListening

    def beta_activate(%@for{ncc_ref: ncc} = node, ncc_token, rete) do
      rete =
        rete
        |> Rete.add_token(ncc_token)
        |> @for.index(node, ncc_token)

      owner = @for.owner_for(node, ncc_token, rete)

      if owner do
        rete = rete |> Rete.add_ncc_token(owner, ncc_token)

        rete
        |> Rete.get_beta(ncc)
        |> NCC.ncc_deactivate(owner, rete)
      else
        rete
      end
    end

    def beta_deactivate(%@for{ncc_ref: ncc} = node, token, rete) do
      # capture owner before removing token, or else we'll lose that information
      owner = Rete.ncc_owner(rete, token)

      rete =
        rete
        |> Rete.remove_token(token)
        |> @for.unindex(node, token)

      if owner && !Rete.has_ncc_tokens?(rete, owner) do
        rete
        |> Rete.get_beta(ncc)
        |> NCC.ncc_activate(owner, rete)
      else
        rete
      end
    end
  end
end
