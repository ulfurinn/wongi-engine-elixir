# credo:disable-for-this-file Credo.Check.Refactor.Nesting
defmodule Wongi.Engine.DSL.Neg do
  @moduledoc false
  alias Wongi.Engine.DSL

  defstruct [:subject, :predicate, :object]

  def new(s, p, o), do: %__MODULE__{subject: s, predicate: p, object: o}

  defimpl DSL.Clause do
    import Wongi.Engine.Compiler

    alias Wongi.Engine.Beta.Negative
    alias Wongi.Engine.DSL.Var
    alias Wongi.Engine.Rete
    alias Wongi.Engine.WME

    def compile(%{subject: s, predicate: p, object: o} = clause, context) do
      acc = {context, %{}, %{}, MapSet.new()}

      {context, tests, assignments, _} =
        [:subject, :predicate, :object]
        |> Enum.reduce(acc, fn field, {context, tests, assignments, local_vars} = acc ->
          case Map.get(clause, field) do
            %Var{name: var} ->
              if MapSet.member?(context.variables, var) || MapSet.member?(local_vars, var) do
                {context, Map.put(tests, field, var), assignments, local_vars}
              else
                {context, tests, Map.put(assignments, field, var), MapSet.put(local_vars, var)}
              end

            _ ->
              acc
          end
        end)

      template = WME.template(s, p, o)

      node = Negative.new(context.node_ref, template, tests, assignments)

      case find_existing(context, node) do
        nil ->
          rete = Rete.subscribe_to_alpha(context.rete, template, node)

          context
          |> put_rete(rete)
          |> advance(node)

        node ->
          context
          |> advance_existing(node)
      end
    end
  end
end
