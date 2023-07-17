defmodule Wongi.Engine.Beta.Production do
  @moduledoc false
  defstruct [:ref, :parent_ref, :actions]

  def new(ref, parent_ref, actions) do
    %__MODULE__{
      ref: ref,
      parent_ref: parent_ref,
      actions: actions
    }
  end

  defimpl Wongi.Engine.Beta do
    alias Wongi.Engine.Action
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

    def beta_activate(%@for{actions: actions}, token, rete) do
      rete = Rete.add_token(rete, token)

      Enum.reduce(actions, rete, fn action, rete ->
        Action.execute(action, token, rete)
      end)
    end

    def beta_deactivate(_, token, rete) do
      Rete.remove_token(rete, token)
    end
  end
end
