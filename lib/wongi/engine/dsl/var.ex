defmodule Wongi.Engine.DSL.Var do
  @moduledoc "Variable declaration."
  defstruct [:name]

  @type t() :: %__MODULE__{name: atom()}

  @doc false
  def new(name) when is_atom(name) do
    %__MODULE__{
      name: name
    }
  end
end
