defmodule Wongi.Engine.DSL.Any do
  @moduledoc false
  defstruct [:clauses]

  def new(clauses) do
    %__MODULE__{
      clauses: clauses
    }
  end

  defimpl Wongi.Engine.DSL.Clause do
    import Wongi.Engine.Compiler

    alias Wongi.Engine.Beta.Or
    alias Wongi.Engine.Compiler
    alias Wongi.Engine.DSL.Clause

    def compile(%@for{clauses: clauses}, context) do
      initial = context

      {context, subcontexts} =
        Enum.reduce(clauses, {context, []}, fn subchain, {context, subcontexts} ->
          # reset visibility, but keep created structures in the rete
          context = %Compiler{initial | rete: context.rete}

          context =
            Enum.reduce(subchain, context, fn clause, context ->
              Clause.compile(clause, context)
            end)

          {context, [context | subcontexts]}
        end)

      subcontexts = Enum.reverse(subcontexts)

      context =
        Enum.reduce(subcontexts, context, fn subcontext, context ->
          Enum.reduce(subcontext.variables, context, fn var, context ->
            declare_variable(context, var)
          end)
        end)

      parent_refs = subcontexts |> Enum.map(& &1.node_ref)

      node = Or.new(parent_refs)

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
