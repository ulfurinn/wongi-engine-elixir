defmodule Wongi.Engine.DSL.Var do
  @moduledoc false
  defstruct [:name]

  def new(name) when is_atom(name) do
    %__MODULE__{
      name: name
    }
  end
end
