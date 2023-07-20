defmodule Wongi.Engine.DSL.Filter do
  @moduledoc false
  defstruct [:filter]

  def new(filter) do
    %__MODULE__{filter: filter}
  end

  defimpl Wongi.Engine.DSL.Clause do
    import Wongi.Engine.Compiler
    alias Wongi.Engine.Beta.Filter

    def compile(clause, context) do
      node = Filter.new(context.node_ref, clause.filter)

      case find_existing(context, node) do
        nil ->
          context
          |> advance(node)

        node ->
          context
          |> advance_existing(node)
      end
    end
  end
end
