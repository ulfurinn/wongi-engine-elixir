defmodule Wongi.Engine.WME do
  @moduledoc false
  alias Wongi.Engine.DSL.Var
  defstruct [:subject, :predicate, :object]

  def new(subject, predicate, object) do
    %__MODULE__{
      subject: subject,
      predicate: predicate,
      object: object
    }
  end

  def new([s, p, o]) do
    %__MODULE__{
      subject: s,
      predicate: p,
      object: o
    }
  end

  def template(s, p, o) do
    new(
      if(dynamic?(s), do: :_, else: s),
      if(dynamic?(p), do: :_, else: p),
      if(dynamic?(o), do: :_, else: o)
    )
  end

  def template([s, p, o]) do
    new(
      if(dynamic?(s), do: :_, else: s),
      if(dynamic?(p), do: :_, else: p),
      if(dynamic?(o), do: :_, else: o)
    )
  end

  defguard wild?(x) when x == :_

  defguard template?(wme)
           when is_map(wme) and
                  (wild?(:erlang.map_get(:subject, wme)) or
                     wild?(:erlang.map_get(:predicate, wme)) or
                     wild?(:erlang.map_get(:object, wme)))

  defguard root?(wme)
           when is_map(wme) and
                  wild?(:erlang.map_get(:subject, wme)) and
                  wild?(:erlang.map_get(:predicate, wme)) and
                  wild?(:erlang.map_get(:object, wme))

  def dynamic?(%Var{}), do: true
  def dynamic?(:_), do: true
  def dynamic?(_), do: false

  def index_pattern(template) do
    [:object, :predicate, :subject]
    |> Enum.reduce({[], []}, fn field, {fields, values} = acc ->
      case template[field] do
        :_ -> acc
        value -> {[field | fields], [value | values]}
      end
    end)
  end

  # could pattern match on it but that might not be faster
  def fetch(%__MODULE__{} = wme, field), do: Map.fetch(wme, field)

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(%@for{subject: s, predicate: p, object: o}, opts) do
      concat([
        "WME.new(",
        Inspect.inspect(s, opts),
        ", ",
        Inspect.inspect(p, opts),
        ", ",
        Inspect.inspect(o, opts),
        ")"
      ])
    end
  end
end
