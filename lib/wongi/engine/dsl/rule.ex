defmodule Wongi.Engine.DSL.Rule do
  @moduledoc false
  @type t() :: %__MODULE__{}
  defstruct [:ref, :name, :forall, :actions]

  @doc false
  def new(name, forall, actions) do
    %__MODULE__{
      ref: make_ref(),
      name: name,
      forall: forall,
      actions: actions
    }
  end
end
