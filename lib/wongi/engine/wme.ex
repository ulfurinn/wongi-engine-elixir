defmodule Wongi.Engine.WME do
  @moduledoc """
  A single fact in the form of `{subject, predicate, object}`.

  "Working Memory Element" in classic Rete terminology.
  """
  alias Wongi.Engine.DSL.Var

  @type t() :: %__MODULE__{}

  defstruct [:subject, :predicate, :object]

  @doc false
  def new(subject, predicate, object) do
    %__MODULE__{
      subject: subject,
      predicate: predicate,
      object: object
    }
  end

  @doc false
  def new({s, p, o}) do
    %__MODULE__{
      subject: s,
      predicate: p,
      object: o
    }
  end

  def new([s, p, o]) do
    %__MODULE__{
      subject: s,
      predicate: p,
      object: o
    }
  end

  @doc false
  def template(s, p, o) do
    new(
      if(dynamic?(s), do: :_, else: s),
      if(dynamic?(p), do: :_, else: p),
      if(dynamic?(o), do: :_, else: o)
    )
  end

  @doc false
  def template({s, p, o}) do
    new(
      if(dynamic?(s), do: :_, else: s),
      if(dynamic?(p), do: :_, else: p),
      if(dynamic?(o), do: :_, else: o)
    )
  end

  @doc false
  defguard wild?(x) when x == :_

  @doc false
  defguard template?(wme)
           when is_map(wme) and
                  (wild?(:erlang.map_get(:subject, wme)) or
                     wild?(:erlang.map_get(:predicate, wme)) or
                     wild?(:erlang.map_get(:object, wme)))

  @doc false
  defguard root?(wme)
           when is_map(wme) and
                  wild?(:erlang.map_get(:subject, wme)) and
                  wild?(:erlang.map_get(:predicate, wme)) and
                  wild?(:erlang.map_get(:object, wme))

  @doc false
  def dynamic?(%Var{}), do: true
  def dynamic?(:_), do: true
  def dynamic?(_), do: false

  @doc false
  def index_pattern(template) do
    [:object, :predicate, :subject]
    |> Enum.reduce({[], []}, fn field, {fields, values} = acc ->
      case template[field] do
        :_ -> acc
        value -> {[field | fields], [value | values]}
      end
    end)
  end

  @spec fetch(t(), :subject | :predicate | :object) :: any()
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
