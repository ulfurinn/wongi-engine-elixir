defmodule Wongi.Engine.DSL.NCC do
  @moduledoc false
  defstruct subchain: []
  def new(subchain), do: %__MODULE__{subchain: subchain}

  defimpl Wongi.Engine.DSL.Clause do
    import Wongi.Engine.Compiler

    alias Wongi.Engine.Beta.NCC
    alias Wongi.Engine.Compiler
    alias Wongi.Engine.DSL.Clause

    def compile(%@for{subchain: subchain}, context) do
      subchain_context =
        Enum.reduce(subchain, context, fn clause, context ->
          Clause.compile(clause, context)
        end)

      {node, partner} = NCC.new_pair(context.node_ref, subchain_context.node_ref)

      %Compiler{rete: rete} = advance(subchain_context, partner)

      context
      |> put_rete(rete)
      |> advance(node)
    end
  end
end
