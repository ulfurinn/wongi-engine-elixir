defmodule Wongi.Engine.Overlay do
  @moduledoc false
  alias Wongi.Engine.AlphaIndex
  alias Wongi.Engine.Beta
  alias Wongi.Engine.WME

  defstruct [
    :wmes,
    :indexes,
    :manual,
    :tokens
  ]

  @index_patterns [
    [:subject],
    [:predicate],
    [:object],
    [:subject, :predicate],
    [:subject, :object],
    [:predicate, :object]
  ]

  def new do
    %__MODULE__{
      wmes: MapSet.new(),
      indexes:
        for pattern <- @index_patterns, into: %{} do
          {pattern, AlphaIndex.new(pattern)}
        end,
      manual: MapSet.new(),
      tokens: %{}
    }
  end

  def has_wme?(%__MODULE__{wmes: wmes}, wme) do
    MapSet.member?(wmes, wme)
  end

  def wmes(%__MODULE__{wmes: wmes}), do: wmes

  def matching(overlay, %WME{} = template) do
    matching(overlay, WME.index_pattern(template))
  end

  def matching(%__MODULE__{indexes: indexes}, {fields, values}) do
    indexes[fields] |> AlphaIndex.get(values)
  end

  def add_wme(overlay, wme, generator)

  def add_wme(overlay, wme, nil) do
    overlay
    |> store_wme(wme)
    |> set_manual(wme)
  end

  def store_wme(%__MODULE__{wmes: wmes} = overlay, wme) do
    if has_wme?(overlay, wme) do
      overlay
    else
      %__MODULE__{overlay | wmes: MapSet.put(wmes, wme)}
      |> index(wme)
    end
  end

  def delete_wme(overlay, wme) do
    if !has_manual?(%__MODULE__{wmes: wmes} = overlay, wme) do
      %__MODULE__{overlay | wmes: MapSet.delete(wmes, wme)}
      |> unindex(wme)
    else
      overlay
    end
  end

  def remove_wme(overlay, wme, generator)

  def remove_wme(overlay, wme, nil) do
    overlay
    |> clear_manual(wme)
    |> delete_wme(wme)
  end

  def add_token(%__MODULE__{tokens: tokens} = overlay, token) do
    node_tokens =
      tokens
      |> Map.get_lazy(token.node_ref, &MapSet.new/0)
      |> MapSet.put(token)

    overlay
    |> put_tokens(token.node_ref, node_tokens)
  end

  def remove_token(%__MODULE__{tokens: tokens} = overlay, token) do
    case Map.fetch(tokens, token.node_ref) do
      {:ok, node_tokens} ->
        overlay
        |> put_tokens(token.node_ref, MapSet.delete(node_tokens, token))

      :error ->
        overlay
    end
  end

  def tokens(%__MODULE__{tokens: tokens}, node) do
    Map.get_lazy(tokens, Beta.ref(node), &MapSet.new/0)
  end

  def index(%__MODULE__{indexes: indexes} = overlay, wme) do
    indexes =
      for {pattern, index} <- indexes, into: %{} do
        {pattern, AlphaIndex.put(index, wme)}
      end

    %__MODULE__{overlay | indexes: indexes}
  end

  def unindex(%__MODULE__{indexes: indexes} = overlay, wme) do
    indexes =
      for {pattern, index} <- indexes, into: %{} do
        {pattern, AlphaIndex.delete(index, wme)}
      end

    %__MODULE__{overlay | indexes: indexes}
  end

  def set_manual(%__MODULE__{manual: manual} = overlay, wme) do
    %__MODULE__{overlay | manual: MapSet.put(manual, wme)}
  end

  def clear_manual(%__MODULE__{manual: manual} = overlay, wme) do
    %__MODULE__{overlay | manual: MapSet.delete(manual, wme)}
  end

  def has_manual?(%__MODULE__{manual: manual}, wme) do
    MapSet.member?(manual, wme)
  end

  defp put_tokens(%__MODULE__{} = overlay, node_ref, tokens) do
    %__MODULE__{overlay | tokens: Map.put(overlay.tokens, node_ref, tokens)}
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(overlay, _opts) do
      container_doc(
        "#Overlay<",
        [
          wmes: overlay.wmes,
          indexes: overlay.indexes,
          manual: overlay.manual,
          tokens: overlay.tokens
        ],
        ">",
        %Inspect.Opts{},
        fn
          {:wmes, wmes}, opts ->
            concat(["wmes: (length=", Inspect.inspect(MapSet.size(wmes), opts), ")"])

          {:indexes, _}, _opts ->
            "indexes: %{...}"

          pair, opts ->
            Inspect.List.keyword(pair, opts)
        end,
        break: :strict
      )
    end
  end
end
