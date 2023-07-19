defmodule Wongi.Engine.DSL.Rule do
  @moduledoc """
  A structure holding a rule definition.
  """
  @type t() :: %__MODULE__{}
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
