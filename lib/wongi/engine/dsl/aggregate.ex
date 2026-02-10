defmodule Wongi.Engine.DSL.Aggregate do
  @moduledoc false
  alias Wongi.Engine.DSL.Var

  defstruct [:fun, :var, opts: []]

  def new(fun, %Var{name: name}, opts), do: %__MODULE__{fun: fun, var: name, opts: opts}
  def new(fun, var, opts) when is_atom(var), do: %__MODULE__{fun: fun, var: var, opts: opts}

  defimpl Wongi.Engine.DSL.Clause do
    import Wongi.Engine.Compiler
    alias Wongi.Engine.Beta.Aggregate

    def compile(clause, context) do
      # TODO: undeclare all variables that are not output/partition variables
      context = declare_variable(context, clause.var)

      node =
        Aggregate.new(context.node_ref, clause.var, clause.fun, clause.opts)

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
