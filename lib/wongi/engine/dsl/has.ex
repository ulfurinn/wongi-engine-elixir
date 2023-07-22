# credo:disable-for-this-file Credo.Check.Refactor.Nesting
defmodule Wongi.Engine.DSL.Has do
  @moduledoc false
  alias Wongi.Engine.DSL
  defstruct [:subject, :predicate, :object, :filters]

  def new(subject, predicate, object, opts \\ []) do
    %__MODULE__{
      subject: subject,
      predicate: predicate,
      object: object,
      filters: opts[:when]
    }
  end

  defimpl DSL.Clause do
    import Wongi.Engine.Compiler

    alias Wongi.Engine.Beta.Join
    alias Wongi.Engine.DSL.Var
    alias Wongi.Engine.Rete
    alias Wongi.Engine.WME

    def compile(%@for{subject: s, predicate: p, object: o, filters: filters} = clause, context) do
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

      template = WME.template(s, p, o)

      filters = extract_filters(filters)

      node = Join.new(context.node_ref, template, tests, assignments, when: filters)

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

    defp extract_filters(nil), do: nil
    defp extract_filters(%Wongi.Engine.DSL.Filter{filter: filter}), do: filter
    defp extract_filters(filters) when is_list(filters), do: Enum.map(filters, &extract_filters/1)
  end
end
