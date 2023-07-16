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
      {context, tests} =
        [:subject, :predicate, :object]
        |> Enum.reduce({context, %{}}, fn field, {context, tests} = acc ->
          case Map.get(clause, field) do
            %Var{name: var} ->
              if MapSet.member?(context.variables, var) do
                {context, Map.put(tests, field, var)}
              else
                raise "unbound varaible #{var} in neg clause; neg nodes may not introduce new variables"
              end

            _ ->
              acc
          end
        end)

      template = WME.template(s, p, o)

      node = Negative.new(context.node_ref, template, tests)

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
