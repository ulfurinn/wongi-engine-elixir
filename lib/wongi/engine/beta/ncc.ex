defmodule Wongi.Engine.Beta.NCC do
  @moduledoc false
  alias Wongi.Engine.Beta.Common
  alias Wongi.Engine.Beta.NCC.Partner
  alias Wongi.Engine.Rete
  alias Wongi.Engine.Token

  @type t() :: %__MODULE__{}
  defstruct [:ref, :parent_ref, :partner_ref]

  def new_pair(main_parent_ref, subchain_parent_ref) do
    main_ref = make_ref()
    partner_ref = make_ref()

    ncc = %__MODULE__{
      ref: main_ref,
      parent_ref: main_parent_ref,
      partner_ref: partner_ref
    }

    partner = %Partner{
      ref: partner_ref,
      parent_ref: subchain_parent_ref,
      ncc_ref: main_ref
    }

    {ncc, partner}
  end

  def ncc_activate(node, token, rete) do
    rete
    |> Rete.beta_subscriptions(node)
    |> Common.beta_activate(&Token.new(&1, [token], nil), rete)
  end

  def ncc_deactivate(node, token, rete) do
    rete
    |> Rete.beta_subscriptions(node)
    |> Common.beta_deactivate(token, rete)
  end

  defimpl Wongi.Engine.Beta do
    alias Wongi.Engine.Beta.Common
    alias Wongi.Engine.Beta.NCC.Partner
    alias Wongi.Engine.Rete
    alias Wongi.Engine.Token

    def ref(%@for{ref: ref}), do: ref
    def parent_refs(%@for{parent_ref: parent_ref}), do: [parent_ref]

    def seed(node, beta, rete) do
      Rete.tokens(rete, node)
      |> Enum.reject(&Rete.has_ncc_tokens?(rete, &1))
      |> Enum.reduce(rete, fn token, rete ->
        Common.beta_activate([beta], &Token.new(&1, [token], nil), rete)
      end)
    end

    # equivalence is a bit to think about weird for NCC
    def equivalent?(_, _, _), do: false

    @spec alpha_activate(
            Wongi.Engine.Beta.NCC.t(),
            Wongi.Engine.WME.t(),
            Wongi.Engine.Rete.t()
          ) :: no_return()
    defdelegate alpha_activate(node, alpha, rete), to: Wongi.Engine.Beta.NonAlphaListening

    @spec alpha_deactivate(
            Wongi.Engine.Beta.NCC.t(),
            Wongi.Engine.WME.t(),
            Wongi.Engine.Rete.t()
          ) :: no_return()
    defdelegate alpha_deactivate(node, alpha, rete), to: Wongi.Engine.Beta.NonAlphaListening

    def beta_activate(%@for{partner_ref: partner} = node, token, rete) do
      rete = Rete.add_token(rete, token)

      rete =
        rete
        |> Rete.tokens(partner)
        |> Enum.reduce(rete, fn ncc_token, rete ->
          if Partner.owner_token?(token, ncc_token) do
            Rete.add_ncc_token(rete, token, ncc_token)
          else
            rete
          end
        end)

      if Rete.has_ncc_tokens?(rete, token) do
        rete
      else
        rete
        |> Rete.beta_subscriptions(node)
        |> Common.beta_activate(&Token.new(&1, [token], nil), rete)
      end
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
