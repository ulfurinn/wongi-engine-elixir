# credo:disable-for-this-file Credo.Check.Refactor.Nesting
defmodule Wongi.Engine.DSL.Has do
  @moduledoc false
  alias Wongi.Engine.DSL
  defstruct [:subject, :predicate, :object]

  def new(subject, predicate, object) do
    %__MODULE__{
      subject: subject,
      predicate: predicate,
      object: object
    }
  end

  defimpl DSL.Clause do
    import Wongi.Engine.Compiler

    alias Wongi.Engine.Beta.Join
    alias Wongi.Engine.DSL.Var
    alias Wongi.Engine.Rete
    alias Wongi.Engine.WME

    def compile(%@for{subject: s, predicate: p, object: o} = clause, context) do
      {context, tests, assignments} =
        [:subject, :predicate, :object]
        |> Enum.reduce({context, %{}, %{}}, fn field, {context, tests, assignments} = acc ->
          case Map.get(clause, field) do
            %Var{name: var} ->
              if MapSet.member?(context.variables, var) do
                {context, Map.put(tests, field, var), assignments}
              else
                context = context |> declare_variable(var)
                {context, tests, Map.put(assignments, field, var)}
              end

            _ ->
              acc
          end
        end)

      template =
        WME.new(
          if(dynamic?(s), do: :_, else: s),
          if(dynamic?(p), do: :_, else: p),
          if(dynamic?(o), do: :_, else: o)
        )

      node = Join.new(context.node_ref, template, tests, assignments)

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
