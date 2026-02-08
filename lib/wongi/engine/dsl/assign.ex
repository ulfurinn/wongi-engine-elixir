defmodule Wongi.Engine.DSL.Assign do
  @moduledoc false
  alias Wongi.Engine.DSL.Var

  defstruct [:name, :value]

  @doc """
  Create a new Assign clause.

  The `name` can be an atom or a `%Var{}` struct. If a Var struct is provided,
  the atom name is extracted for storage in the token.
  """
  def new(%Var{name: name}, value), do: %__MODULE__{name: name, value: value}
  def new(name, value) when is_atom(name), do: %__MODULE__{name: name, value: value}

  defimpl Wongi.Engine.DSL.Clause do
    import Wongi.Engine.Compiler
    alias Wongi.Engine.Beta.Assign

    def compile(%@for{name: name, value: value}, context) do
      node = Assign.new(context.node_ref, name, value)

      case find_existing(context, node) do
        nil ->
          context
          |> declare_variable(name)
          |> advance(node)

        node ->
          context
          |> advance_existing(node)
      end
    end
  end
end
