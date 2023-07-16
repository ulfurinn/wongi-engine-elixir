defmodule Wongi.Engine.Overlay do
  @moduledoc false
  alias Wongi.Engine.AlphaIndex
  alias Wongi.Engine.Beta
  alias Wongi.Engine.Token
  alias Wongi.Engine.WME

  defmodule JoinResults do
    @moduledoc false
    defstruct [:by_wme, :by_token]

    def new do
      %__MODULE__{
        by_wme: %{},
        by_token: %{}
      }
    end

    def put(%__MODULE__{by_wme: by_wme, by_token: by_token}, token, wme) do
      by_wme =
        by_wme
        |> Map.put_new_lazy(wme, &MapSet.new/0)
        |> Map.update!(wme, &MapSet.put(&1, {token, wme}))

      by_token =
        by_token
        |> Map.put_new_lazy(token, &MapSet.new/0)
        |> Map.update!(token, &MapSet.put(&1, {token, wme}))

      %__MODULE__{
        by_wme: by_wme,
        by_token: by_token
      }
    end

    def delete(%__MODULE__{by_wme: by_wme, by_token: by_token}, {token, wme} = jr) do
      by_wme =
        by_wme
        |> Map.update!(wme, &MapSet.delete(&1, jr))
        |> delete_if(wme, &Enum.empty?/1)

      by_token =
        by_token
        |> Map.update!(token, &MapSet.delete(&1, jr))
        |> delete_if(token, &Enum.empty?/1)

      %__MODULE__{
        by_wme: by_wme,
        by_token: by_token
      }
    end

    def delete(%__MODULE__{by_token: by_token} = njrs, %Token{} = token) do
      case Map.fetch(by_token, token) do
        {:ok, jrs} -> Enum.reduce(jrs, njrs, &delete(&2, &1))
        _ -> njrs
      end
    end

    def get(%__MODULE__{by_wme: by_wme}, %WME{} = wme) do
      Map.get_lazy(by_wme, wme, &MapSet.new/0)
    end

    def get(%__MODULE__{by_token: by_token}, %Token{} = token) do
      Map.get_lazy(by_token, token, &MapSet.new/0)
    end

    defp delete_if(%{} = map, key, predicate) do
      if predicate.(Map.get(map, key)) do
        Map.delete(map, key)
      else
        map
      end
    end
  end

  defstruct [
    :wmes,
    :indexes,
    :manual,
    :tokens,
    :neg_join_results
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
      neg_join_results: JoinResults.new()
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

  defp can_delete_wme?(overlay, wme), do: !has_manual?(overlay, wme)

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
        |> remove_neg_join_result(token)

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

  defp put_neg_join_results(overlay, jrs) do
    %__MODULE__{overlay | neg_join_results: jrs}
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
