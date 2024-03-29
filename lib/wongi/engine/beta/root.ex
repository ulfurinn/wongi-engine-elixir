defmodule Wongi.Engine.Beta.Root do
  @moduledoc false

  alias Wongi.Engine.Token

  @type t() :: %__MODULE__{}
  defstruct [:ref]

  def new do
    %__MODULE__{
      ref: make_ref()
    }
  end

  def seed(_beta, rete) do
    rete
  end

  defimpl Wongi.Engine.Beta do
    alias Wongi.Engine.Beta

    def ref(%@for{ref: ref}) do
      ref
    end

    def parent_refs(_), do: []

    def seed(%@for{}, beta, rete) do
      Beta.beta_activate(beta, Token.new(beta, [], nil), rete)
    end

    def equivalent?(
          %@for{},
          %@for{},
          _rete
        ),
        do: true

    def equivalent?(_, _, _), do: false

    @spec alpha_activate(Wongi.Engine.Beta.Root.t(), Wongi.Engine.WME.t(), Wongi.Engine.Rete.t()) ::
            no_return()
    defdelegate alpha_activate(node, alpha, rete), to: Wongi.Engine.Beta.NonAlphaListening

    @spec alpha_deactivate(
            Wongi.Engine.Beta.Root.t(),
            Wongi.Engine.WME.t(),
            Wongi.Engine.Rete.t()
          ) :: no_return()
    defdelegate alpha_deactivate(node, alpha, rete), to: Wongi.Engine.Beta.NonAlphaListening

    def beta_activate(%@for{ref: _ref}, _token, rete) do
      rete
    end

    def beta_deactivate(%@for{ref: _ref}, _token, rete) do
      rete
    end
  end
end
