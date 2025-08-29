defmodule Wongi.Engine.Action.Generator do
  @moduledoc false
  alias Wongi.Engine.WME
  defstruct [:template, :generator]

  def new(s, p, o) do
    %__MODULE__{
      template: WME.new(s, p, o)
    }
  end

  def new(fun) do
    %__MODULE__{
      generator: fun
    }
  end

  defimpl Wongi.Engine.Action do
    alias Wongi.Engine.DSL.Var
    alias Wongi.Engine.Rete

    def execute(%@for{template: template}, token, rete) when template != nil do
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

    def execute(%@for{generator: fun}, token, rete) when is_function(fun, 1) do
      fun.(token)
      |> List.wrap()
      |> Enum.reduce(rete, fn wme, rete ->
        Rete.assert(rete, wme, token)
      end)
    end

    def deexecute(_, _, rete) do
      rete
    end
  end
end
