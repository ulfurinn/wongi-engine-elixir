defmodule Wongi.Engine.Beta.Production do
  @moduledoc false
  defstruct [:ref, :parent_ref]

  def new(ref, parent_ref) do
    %__MODULE__{
      ref: ref,
      parent_ref: parent_ref
    }
  end

  defimpl Wongi.Engine.Beta do
    alias Wongi.Engine.Rete

    require Logger

    def ref(%@for{ref: ref}), do: ref
    def parent_ref(%@for{parent_ref: parent_ref}), do: parent_ref
    def seed(_, _, _), do: raise("production nodes cannot have descendants")

    def equivalent?(
          %@for{ref: r, parent_ref: p},
          %@for{ref: r, parent_ref: p},
          _rete
        ),
        do: true

    def equivalent?(_, _, _), do: false
    def alpha_activate(_, _, _), do: raise("production nodes cannot be alpha activated")
    def alpha_deactivate(_, _, _), do: raise("production nodes cannot be alpha deactivated")

    def beta_activate(_, token, rete) do
      Rete.add_token(rete, token)
    end

    def beta_deactivate(_, token, rete) do
      Rete.remove_token(rete, token)
    end
  end
end
