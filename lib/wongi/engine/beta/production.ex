defmodule Wongi.Engine.Beta.Production do
  @moduledoc false

  @type t() :: %__MODULE__{}
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

    @spec alpha_activate(
            Wongi.Engine.Beta.Production.t(),
            Wongi.Engine.WME.t(),
            Wongi.Engine.Rete.t()
          ) :: no_return()
    defdelegate alpha_activate(node, alpha, rete), to: Wongi.Engine.Beta.NonAlphaListening

    @spec alpha_deactivate(
            Wongi.Engine.Beta.Production.t(),
            Wongi.Engine.WME.t(),
            Wongi.Engine.Rete.t()
          ) :: no_return()
    defdelegate alpha_deactivate(node, alpha, rete), to: Wongi.Engine.Beta.NonAlphaListening

    def beta_activate(%@for{actions: actions}, token, rete) do
      rete = Rete.add_token(rete, token)

      Enum.reduce(actions, rete, fn action, rete ->
        Action.execute(action, token, rete)
      end)
    end

    def beta_deactivate(%@for{actions: actions}, token, rete) do
      rete = Rete.remove_token(rete, token)

      Enum.reduce(actions, rete, fn action, rete ->
        Action.deexecute(action, token, rete)
      end)
    end
  end
end
