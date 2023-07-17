defmodule Wongi.Engine.Action.Generator do
  alias Wongi.Engine.WME
  defstruct [:template]

  def new(s, p, o) do
    %__MODULE__{
      template: WME.new(s, p, o)
    }
  end

  defimpl Wongi.Engine.Action do
    alias Wongi.Engine.DSL.Var
    alias Wongi.Engine.Rete

    def execute(%@for{template: template}, token, rete) do
      wme =
        [:subject, :predicate, :object]
        |> Enum.map(fn field ->
          case template[field] do
            %Var{name: name} -> token[name]
            literal -> literal
          end
        end)
        |> WME.new()

      # consistency check

      Rete.assert(rete, wme, token)
    end

    def deexecute(_, _, rete) do
      rete
    end
  end
end
