defmodule Wongi.Engine.Overlay do
  @moduledoc false
  alias Wongi.Engine.AlphaIndex
  alias Wongi.Engine.Beta
  alias Wongi.Engine.Overlay.GenerationTracker
  alias Wongi.Engine.Overlay.JoinResults
  alias Wongi.Engine.WME

  require Logger

  @type t() :: %__MODULE__{}
  defstruct [
    :wmes,
    :indexes,
    :manual,
    :tokens,
    :neg_join_results,
    :generation_tracker
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
      tokens: %{},
      neg_join_results: JoinResults.new(),
      generation_tracker: GenerationTracker.new()
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

  def add_wme(overlay, wme, generating_token) do
    overlay
    |> store_wme(wme)
    |> track_generation(wme, generating_token)
  end

  def store_wme(%__MODULE__{wmes: wmes} = overlay, wme) do
    if has_wme?(overlay, wme) do
      overlay
    else
      %__MODULE__{overlay | wmes: MapSet.put(wmes, wme)}
      |> index(wme)
    end
  end

  defp can_delete_wme?(%__MODULE__{generation_tracker: tracker} = overlay, wme) do
    !has_manual?(overlay, wme) && GenerationTracker.empty?(tracker, wme)
  end

  def delete_wme(%__MODULE__{wmes: wmes} = overlay, wme) do
    if can_delete_wme?(overlay, wme) do
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

  def remove_wme(overlay, wme, _generator) do
    overlay
    |> delete_wme(wme)
  end

  @spec add_token(t(), Wongi.Engine.Token.t()) :: t()
  def add_token(%__MODULE__{tokens: tokens} = overlay, %Wongi.Engine.Token{} = token) do
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
        |> remove_neg_join_result(token)
        |> remove_generator(token)

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

  def add_neg_join_result(%__MODULE__{neg_join_results: jrs} = overlay, token, wme) do
    overlay
    |> put_neg_join_results(JoinResults.put(jrs, token, wme))
  end

  def remove_neg_join_result(%__MODULE__{neg_join_results: jrs} = overlay, token, wme) do
    overlay
    |> put_neg_join_results(JoinResults.delete(jrs, {token, wme}))
  end

  def remove_neg_join_result(%__MODULE__{neg_join_results: jrs} = overlay, token) do
    overlay
    |> put_neg_join_results(JoinResults.delete(jrs, token))
  end

  def neg_join_results(%__MODULE__{neg_join_results: jrs}, token_or_wme) do
    JoinResults.get(jrs, token_or_wme)
  end

  def track_generation(%__MODULE__{generation_tracker: tracker} = overlay, wme, token) do
    overlay
    |> put_generation_tracker(GenerationTracker.add(tracker, wme, token))
  end

  def remove_generator(%__MODULE__{generation_tracker: tracker} = overlay, token) do
    overlay
    |> put_generation_tracker(GenerationTracker.remove(tracker, token))
  end

  def generated_wmes(%__MODULE__{generation_tracker: tracker}, token) do
    GenerationTracker.get(tracker, token)
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

  defp put_tokens(%__MODULE__{} = overlay, node_ref, node_tokens) do
    tokens =
      if Enum.empty?(node_tokens) do
        Map.delete(overlay.tokens, node_ref)
      else
        Map.put(overlay.tokens, node_ref, node_tokens)
      end

    %__MODULE__{overlay | tokens: tokens}
  end

  defp put_neg_join_results(overlay, jrs) do
    %__MODULE__{overlay | neg_join_results: jrs}
  end

  defp put_generation_tracker(overlay, tracker) do
    %__MODULE__{overlay | generation_tracker: tracker}
  end
end
