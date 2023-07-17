defmodule Wongi.Engine.DSL.Rule do
  @moduledoc false
  defstruct [:ref, :name, :forall, :actions]

  def new(name, forall, actions) do
    %__MODULE__{
      ref: make_ref(),
      name: name,
      forall: forall,
      actions: actions
    }
  end
end
