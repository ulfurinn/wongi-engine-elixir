defmodule Wongi.Engine.Overlay do
  @moduledoc false
  alias Wongi.Engine.AlphaIndex
  alias Wongi.Engine.Beta
  alias Wongi.Engine.Overlay.GenerationTracker
  alias Wongi.Engine.Overlay.JoinResults
  alias Wongi.Engine.Token
  alias Wongi.Engine.WME

  @type t() :: %__MODULE__{}
  defstruct [
    :wmes,
    :indexes,
    :manual,
    :tokens,
    :neg_join_results,
    :generation_tracker,
    :ncc_tokens,
    :ncc_owners
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
      generation_tracker: GenerationTracker.new(),
      ncc_tokens: %{},
      ncc_owners: %{}
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
        |> remove_ncc(token)

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

  def add_ncc_token(
        %__MODULE__{ncc_tokens: ncc_tokens, ncc_owners: ncc_owners} = overlay,
        %Token{ref: ref} = token,
        ncc_token
      ) do
    tokens =
      case ncc_tokens do
        %{^ref => tokens} -> MapSet.put(tokens, ncc_token)
        _ -> MapSet.new([ncc_token])
      end

    ncc_tokens = Map.put(ncc_tokens, token.ref, tokens)
    ncc_owners = Map.put(ncc_owners, ncc_token.ref, token)
    %__MODULE__{overlay | ncc_tokens: ncc_tokens, ncc_owners: ncc_owners}
  end

  def ncc_owner(%__MODULE__{ncc_owners: ncc_owners}, %Token{ref: ref}) do
    Map.get(ncc_owners, ref)
  end

  def has_ncc_tokens?(%__MODULE__{ncc_tokens: ncc_tokens}, %Token{ref: ref}) do
    case ncc_tokens do
      %{^ref => tokens} -> !Enum.empty?(tokens)
      _ -> false
    end
  end

  defp remove_ncc(
         %__MODULE__{ncc_tokens: ncc_tokens, ncc_owners: ncc_owners} = overlay,
         token
       ) do
    {ncc_tokens, ncc_owners} =
      {ncc_tokens, ncc_owners}
      |> remove_ncc_partner_token(token)
      |> remove_ncc_owner_token(token)

    %__MODULE__{overlay | ncc_tokens: ncc_tokens, ncc_owners: ncc_owners}
  end

  defp remove_ncc_partner_token({ncc_tokens, ncc_owners}, %Token{ref: ref} = token) do
    case ncc_owners do
      %{^ref => %Token{ref: owner_ref}} ->
        ncc_owners = Map.delete(ncc_owners, ref)

        ncc_tokens_of_owner =
          Map.get(ncc_tokens, owner_ref)
          |> MapSet.delete(token)

        ncc_tokens =
          if Enum.empty?(ncc_tokens_of_owner) do
            ncc_tokens |> Map.delete(owner_ref)
          else
            ncc_tokens |> Map.put(owner_ref, ncc_tokens_of_owner)
          end

        {ncc_tokens, ncc_owners}

      _ ->
        {ncc_tokens, ncc_owners}
    end
  end

  defp remove_ncc_owner_token({ncc_tokens, ncc_owners}, %Token{ref: ref}) do
    case ncc_tokens do
      %{^ref => tokens} ->
        ncc_owners =
          Enum.reduce(tokens, ncc_owners, fn %Token{ref: partner_ref}, ncc_owners ->
            Map.delete(ncc_owners, partner_ref)
          end)

        ncc_tokens = Map.delete(ncc_tokens, ref)
        {ncc_tokens, ncc_owners}

      _ ->
        {ncc_tokens, ncc_owners}
    end
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
