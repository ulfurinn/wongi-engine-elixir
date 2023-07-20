defmodule Wongi.Engine.DSL.Assign do
  defstruct [:name, :value]

  def new(name, value), do: %__MODULE__{name: name, value: value}

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
