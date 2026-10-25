defmodule Wongi.Engine.Rete do
  @moduledoc false
  import Wongi.Engine.WME, only: [root?: 1, template?: 1]

  alias Wongi.Engine.AlphaIndex
  alias Wongi.Engine.Beta
  alias Wongi.Engine.Beta.Root
  alias Wongi.Engine.Compiler
  alias Wongi.Engine.JoinResults
  alias Wongi.Engine.Token
  alias Wongi.Engine.WME

  @alpha_patterns [
    [:_, :_, :_],
    [:subject, :_, :_],
    [:_, :predicate, :_],
    [:_, :_, :object],
    [:subject, :predicate, :_],
    [:subject, :_, :object],
    [:_, :predicate, :object],
    [:subject, :predicate, :object]
  ]

  @index_patterns [
    [:subject],
    [:predicate],
    [:object],
    [:subject, :predicate],
    [:subject, :object],
    [:predicate, :object]
  ]

  @type t() :: %__MODULE__{}

  defstruct [
    :wmes,
    :indexes,
    :manual,
    :tokens,
    :tokens_by_parent,
    :tokens_by_wme,
    :neg_join_results,
    :ncc_tokens,
    :ncc_owners,
    :retracting,
    :pending_alpha,
    # ---
    :generation_by_wme,
    :generation_by_token,
    # ---
    :alpha_subscriptions,
    :beta_root,
    :beta_table,
    :beta_subscriptions,
    :productions
  ]

  def new do
    root = Root.new()

    %__MODULE__{
      wmes: MapSet.new(),
      indexes:
        for pattern <- @index_patterns, into: %{} do
          {pattern, AlphaIndex.new(pattern)}
        end,
      manual: MapSet.new(),
      tokens: %{},
      tokens_by_parent: %{},
      tokens_by_wme: %{},
      neg_join_results: JoinResults.new(),
      ncc_tokens: %{},
      ncc_owners: %{},
      retracting: MapSet.new(),
      pending_alpha: %{},
      # ---
      generation_by_wme: %{},
      generation_by_token: %{},
      # ---
      alpha_subscriptions: %{},
      beta_root: root,
      beta_table: %{Beta.ref(root) => root},
      beta_subscriptions: %{},
      productions: MapSet.new()
    }
    |> seed()
  end

  @spec compile(t(), Wongi.Engine.DSL.Rule.t()) :: t()
  def compile(rete, rule) do
    Compiler.compile(rete, rule)
    |> add_production(rule.ref)
  end

  @spec compile_and_get_ref(t(), Wongi.Engine.DSL.Rule.t()) :: {t(), reference()}
  def compile_and_get_ref(rete, rule) do
    {compile(rete, rule), rule.ref}
  end

  def assert(rete, wme_ish, generator \\ nil)

  def assert(rete, %WME{} = wme, generator) do
    rete
    |> handle_operation({:assert, wme, generator})
  end

  def assert(rete, {s, p, o}, generator),
    do: assert(rete, WME.new(s, p, o), generator)

  def assert(rete, subject, object, predicate, generator \\ nil)

  def assert(rete, s, p, o, generator),
    do: assert(rete, WME.new(s, p, o), generator)

  def retract(rete, wme_ish, generator \\ nil)

  def retract(rete, %WME{} = wme, generator) do
    rete
    |> handle_operation({:retract, wme, generator})
  end

  def retract(rete, {s, p, o}, generator),
    do: retract(rete, WME.new(s, p, o), generator)

  def retract(rete, subject, object, predicate, generator \\ nil)

  def retract(rete, s, p, o, generator),
    do: retract(rete, WME.new(s, p, o), generator)

  def select(%__MODULE__{} = rete, %WME{} = wme) when not template?(wme) do
    if has_wme?(rete, wme) do
      MapSet.new([wme])
    else
      MapSet.new()
    end
  end

  def select(%__MODULE__{wmes: wmes}, %WME{} = wme) when root?(wme) do
    wmes
  end

  def select(%__MODULE__{} = rete, %WME{} = wme) do
    rete
    |> matching(wme)
  end

  def select(rete, {s, p, o}),
    do: select(rete, WME.new(s, p, o))

  def select(rete, s, p, o),
    do: select(rete, WME.new(s, p, o))

  def subscribe_to_alpha(
        %__MODULE__{alpha_subscriptions: alpha_subscriptions} = rete,
        %WME{} = template,
        node
      ) do
    key = [template.subject, template.predicate, template.object]

    subscriptions = alpha_subscriptions |> Map.get(key, [])
    subscriptions = [Beta.ref(node) | subscriptions]

    alpha_subscriptions = Map.put(alpha_subscriptions, key, subscriptions)

    %__MODULE__{rete | alpha_subscriptions: alpha_subscriptions}
  end

  def subscribe_to_alpha(rete, [s, p, o], node),
    do: subscribe_to_alpha(rete, WME.new(s, p, o), node)

  def add_beta(%__MODULE__{beta_table: beta_table} = rete, node) do
    ref = Beta.ref(node)

    rete = put_beta_table(rete, Map.put(beta_table, ref, node))

    Enum.reduce(Beta.parent_refs(node), rete, &subscribe_to_beta(&2, &1, ref))
  end

  def subscribe_to_beta(
        %__MODULE__{beta_subscriptions: beta_subscriptions} = rete,
        parent,
        child
      )
      when is_reference(parent) and is_reference(child) do
    rete
    |> put_beta_subscriptions(subscribe_to_beta(beta_subscriptions, parent, child))
  end

  def subscribe_to_beta(%__MODULE__{} = rete, parent, child)
      when is_reference(parent) do
    subscribe_to_beta(rete, parent, Beta.ref(child))
  end

  def subscribe_to_beta(subscriptions, parent, child) do
    parent_subs = Map.get(subscriptions, parent, [])
    Map.put(subscriptions, parent, [child | parent_subs])
  end

  def get_beta(%__MODULE__{beta_table: beta_table}, ref) when is_reference(ref) do
    Map.get(beta_table, ref)
  end

  def get_beta(%__MODULE__{beta_table: beta_table}, beta_node) do
    Map.get(beta_table, Beta.ref(beta_node))
  end

  defp seed(%__MODULE__{beta_root: beta_root} = rete) do
    Root.seed(beta_root, rete)
  end

  defp handle_operation(rete, {:assert, wme, generator}) do
    rete
    |> do_assert(wme, generator)
  end

  defp handle_operation(rete, {:retract, wme, generator}) do
    rete
    |> do_retract(wme, generator)
  end

  # While a WME is being retracted, anything derived from it may still assert it
  # again. That only adds a source here, and the retraction then puts it back.
  defp do_assert(%__MODULE__{retracting: retracting} = rete, wme, generator) do
    if MapSet.member?(retracting, wme) do
      add_source(rete, wme, generator)
    else
      rete
      |> put_wme(wme)
      |> add_source(wme, generator)
      |> activate(wme, has_wme?(rete, wme))
    end
  end

  # A WME that is still asserted manually or still generated by another token
  # stays, but its remaining support may itself depend on it, as with facts
  # generated in a cycle. So it is removed in any case, along with everything
  # derived from it, and put back only if it is still supported after that.
  defp do_retract(%__MODULE__{} = rete, wme, generator) do
    rete = remove_source(rete, wme, generator)

    if has_wme?(rete, wme) do
      rete =
        rete
        |> delete_wme(wme)
        |> put_retracting(wme, true)
        |> deactivate(wme)
        |> put_retracting(wme, false)

      if can_delete_wme?(rete, wme) do
        rete
      else
        rete
        |> put_wme(wme)
        |> activate(wme, false)
      end
    else
      rete
    end
  end

  defp put_retracting(%__MODULE__{retracting: retracting} = rete, wme, true),
    do: %__MODULE__{rete | retracting: MapSet.put(retracting, wme)}

  defp put_retracting(%__MODULE__{retracting: retracting} = rete, wme, false),
    do: %__MODULE__{rete | retracting: MapSet.delete(retracting, wme)}

  defp put_wme(%__MODULE__{wmes: wmes} = rete, wme) do
    if has_wme?(rete, wme) do
      rete
    else
      %__MODULE__{rete | wmes: MapSet.put(wmes, wme)}
      |> index(wme)
    end
  end

  defp add_source(rete, wme, nil), do: set_manual(rete, wme)
  defp add_source(rete, wme, generating_token), do: track_generation(rete, wme, generating_token)

  # A generating token has already been removed from the generation records
  # when it retracts its WMEs.
  defp remove_source(rete, wme, nil), do: clear_manual(rete, wme)
  defp remove_source(rete, _wme, _generator), do: rete

  defp can_delete_wme?(%__MODULE__{} = rete, wme) do
    !has_manual?(rete, wme) && not generated?(rete, wme)
  end

  defp delete_wme(%__MODULE__{wmes: wmes} = rete, wme) do
    %__MODULE__{rete | wmes: MapSet.delete(wmes, wme)}
    |> unindex(wme)
  end

  defp activate(rete, wme, existing)
  defp activate(rete, _, true), do: rete

  # A node may receive the WME through a beta activation before its own alpha
  # activation comes, when another node it was delivered to earlier generates
  # facts that reach it. The nodes the WME has yet to be delivered to are
  # recorded as pending, so that they can leave it to the alpha activation
  # instead of matching it twice.
  defp activate(%__MODULE__{pending_alpha: pending} = rete, wme, false) do
    subscriptions =
      rete
      |> alpha_subscriptions(wme)

    {rete, []} =
      Enum.reduce(subscriptions, {rete, subscriptions}, fn node, {rete, [node | rest]} ->
        rete = put_pending_alpha(rete, wme, rest)
        {Beta.alpha_activate(node, wme, rete), rest}
      end)

    # restore whatever an enclosing activation of the same WME had pending
    case pending do
      %{^wme => nodes} -> put_pending_alpha(rete, wme, nodes)
      _ -> put_pending_alpha(rete, wme, [])
    end
  end

  defp put_pending_alpha(%__MODULE__{pending_alpha: pending} = rete, wme, []),
    do: %__MODULE__{rete | pending_alpha: Map.delete(pending, wme)}

  defp put_pending_alpha(%__MODULE__{pending_alpha: pending} = rete, wme, nodes),
    do: %__MODULE__{rete | pending_alpha: Map.put(pending, wme, nodes)}

  @doc false
  def alpha_pending?(%__MODULE__{pending_alpha: pending}, node, wme) do
    case pending do
      %{^wme => nodes} -> Beta.ref(node) in nodes
      _ -> false
    end
  end

  defp deactivate(rete, wme) do
    subscriptions =
      rete
      |> alpha_subscriptions(wme)

    subscriptions |> Enum.reduce(rete, &Beta.alpha_deactivate(&1, wme, &2))
  end

  defp alpha_subscriptions(rete, wme) do
    @alpha_patterns
    |> Enum.flat_map(fn pattern ->
      key =
        Enum.map(pattern, fn
          :_ -> :_
          field -> Map.get(wme, field)
        end)

      Map.get(rete.alpha_subscriptions, key, [])
    end)
  end

  def beta_subscriptions(%__MODULE__{beta_subscriptions: beta_subscriptions}, node) do
    Map.get(beta_subscriptions, Beta.ref(node), [])
  end

  def add_token(%__MODULE__{tokens: tokens} = rete, %Wongi.Engine.Token{} = token) do
    node_tokens =
      tokens
      |> Map.get_lazy(token.node_ref, &MapSet.new/0)
      |> MapSet.put(token)

    rete
    |> put_tokens(token.node_ref, node_tokens)
    |> index_relations(token)
  end

  def remove_token(%__MODULE__{tokens: tokens} = rete, token) do
    wmes = generated_wmes(rete, token)

    rete =
      case Map.fetch(tokens, token.node_ref) do
        {:ok, node_tokens} ->
          rete
          |> put_tokens(token.node_ref, MapSet.delete(node_tokens, token))
          |> unindex_relations(token)
          |> remove_neg_join_result(token)
          |> remove_generator(token)
          |> remove_ncc(token)

        :error ->
          rete
      end

    case wmes do
      nil ->
        rete

      _ ->
        wmes |> Enum.reduce(rete, &retract(&2, &1, token))
    end
  end

  @doc false
  def child_tokens(%__MODULE__{tokens_by_parent: index}, node, %Token{ref: parent_ref}) do
    Map.get(index, {Beta.ref(node), parent_ref}, [])
  end

  @doc false
  def tokens_with_wme(%__MODULE__{tokens_by_wme: index}, node, %WME{} = wme) do
    Map.get(index, {Beta.ref(node), wme}, [])
  end

  defp index_relations(%__MODULE__{} = rete, %Token{node_ref: node_ref} = token) do
    by_parent =
      Enum.reduce(token.parents, rete.tokens_by_parent, fn parent, acc ->
        multi_put(acc, {node_ref, parent.ref}, token)
      end)

    by_wme =
      case token.wme do
        nil -> rete.tokens_by_wme
        wme -> multi_put(rete.tokens_by_wme, {node_ref, wme}, token)
      end

    %__MODULE__{rete | tokens_by_parent: by_parent, tokens_by_wme: by_wme}
  end

  defp unindex_relations(%__MODULE__{} = rete, %Token{node_ref: node_ref} = token) do
    by_parent =
      Enum.reduce(token.parents, rete.tokens_by_parent, fn parent, acc ->
        multi_delete(acc, {node_ref, parent.ref}, token)
      end)

    by_wme =
      case token.wme do
        nil -> rete.tokens_by_wme
        wme -> multi_delete(rete.tokens_by_wme, {node_ref, wme}, token)
      end

    %__MODULE__{rete | tokens_by_parent: by_parent, tokens_by_wme: by_wme}
  end

  defp multi_put(index, key, token) do
    Map.update(index, key, MapSet.new([token]), &MapSet.put(&1, token))
  end

  defp multi_delete(index, key, token) do
    case index do
      %{^key => set} ->
        set = MapSet.delete(set, token)
        if Enum.empty?(set), do: Map.delete(index, key), else: Map.put(index, key, set)

      _ ->
        index
    end
  end

  def tokens(%__MODULE__{tokens: tokens}, node) do
    Map.get_lazy(tokens, Beta.ref(node), &MapSet.new/0)
  end

  def add_neg_join_result(%__MODULE__{neg_join_results: jrs} = rete, token, wme) do
    rete
    |> put_neg_join_results(JoinResults.put(jrs, token, wme))
  end

  def remove_neg_join_result(%__MODULE__{neg_join_results: jrs} = rete, token, wme) do
    rete
    |> put_neg_join_results(JoinResults.delete(jrs, {token, wme}))
  end

  defp remove_neg_join_result(%__MODULE__{neg_join_results: jrs} = rete, token) do
    rete
    |> put_neg_join_results(JoinResults.delete(jrs, token))
  end

  def neg_join_results(%__MODULE__{neg_join_results: jrs}, token_or_wme) do
    JoinResults.get(jrs, token_or_wme)
  end

  def add_ncc_token(
        %__MODULE__{ncc_tokens: ncc_tokens, ncc_owners: ncc_owners} = rete,
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
    %__MODULE__{rete | ncc_tokens: ncc_tokens, ncc_owners: ncc_owners}
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
         %__MODULE__{ncc_tokens: ncc_tokens, ncc_owners: ncc_owners} = rete,
         token
       ) do
    {ncc_tokens, ncc_owners} =
      {ncc_tokens, ncc_owners}
      |> ncc_partner_token(token)
      |> ncc_owner_token(token)

    %__MODULE__{rete | ncc_tokens: ncc_tokens, ncc_owners: ncc_owners}
  end

  defp ncc_partner_token({ncc_tokens, ncc_owners}, %Token{ref: ref} = token) do
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

  defp ncc_owner_token({ncc_tokens, ncc_owners}, %Token{ref: ref}) do
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

  defp add_production(%__MODULE__{productions: productions} = rete, ref) do
    rete
    |> put_productions(MapSet.put(productions, ref))
  end

  @spec productions(Wongi.Engine.Rete.t()) :: any()
  def productions(%__MODULE__{productions: productions}), do: productions

  defp put_beta_table(%__MODULE__{} = rete, beta_table) do
    %__MODULE__{rete | beta_table: beta_table}
  end

  defp put_beta_subscriptions(%__MODULE__{} = rete, beta_subscriptions) do
    %__MODULE__{rete | beta_subscriptions: beta_subscriptions}
  end

  defp put_productions(%__MODULE__{} = rete, productions) do
    %__MODULE__{rete | productions: productions}
  end

  defp has_wme?(%__MODULE__{wmes: wmes}, wme) do
    MapSet.member?(wmes, wme)
  end

  defp matching(rete, %WME{} = template) do
    matching(rete, WME.index_pattern(template))
  end

  defp matching(%__MODULE__{indexes: indexes}, {fields, values}) do
    indexes[fields] |> AlphaIndex.get(values)
  end

  defp index(%__MODULE__{indexes: indexes} = rete, wme) do
    indexes =
      for {pattern, index} <- indexes, into: %{} do
        {pattern, AlphaIndex.put(index, wme)}
      end

    %__MODULE__{rete | indexes: indexes}
  end

  defp unindex(%__MODULE__{indexes: indexes} = rete, wme) do
    indexes =
      for {pattern, index} <- indexes, into: %{} do
        {pattern, AlphaIndex.delete(index, wme)}
      end

    %__MODULE__{rete | indexes: indexes}
  end

  defp track_generation(%__MODULE__{} = rete, wme, token) do
    rete
    |> generation_add(wme, token)
  end

  defp remove_generator(%__MODULE__{} = rete, token) do
    rete
    |> generation_remove(token)
  end

  defp set_manual(%__MODULE__{manual: manual} = rete, wme) do
    %__MODULE__{rete | manual: MapSet.put(manual, wme)}
  end

  defp clear_manual(%__MODULE__{manual: manual} = rete, wme) do
    %__MODULE__{rete | manual: MapSet.delete(manual, wme)}
  end

  defp has_manual?(%__MODULE__{manual: manual}, wme) do
    MapSet.member?(manual, wme)
  end

  defp put_tokens(%__MODULE__{tokens: tokens} = rete, node_ref, node_tokens) do
    tokens =
      if Enum.empty?(node_tokens) do
        Map.delete(tokens, node_ref)
      else
        Map.put(tokens, node_ref, node_tokens)
      end

    %__MODULE__{rete | tokens: tokens}
  end

  defp put_neg_join_results(%__MODULE__{} = rete, jrs) do
    %{rete | neg_join_results: jrs}
  end

  defp generation_add(
         %__MODULE__{generation_by_wme: by_wme, generation_by_token: by_token} = rete,
         wme,
         token
       ) do
    by_wme =
      by_wme
      |> Map.put_new_lazy(wme, &MapSet.new/0)
      |> Map.update!(wme, &MapSet.put(&1, token))

    by_token =
      by_token
      |> Map.put_new_lazy(token, &MapSet.new/0)
      |> Map.update!(token, &MapSet.put(&1, wme))

    %__MODULE__{
      rete
      | generation_by_wme: by_wme,
        generation_by_token: by_token
    }
  end

  defp generated_wmes(%__MODULE__{generation_by_token: by_token}, %Token{} = token) do
    Map.get(by_token, token)
  end

  defp generated?(%__MODULE__{generation_by_wme: by_wme}, %WME{} = wme) do
    Map.has_key?(by_wme, wme)
  end

  defp generation_remove(
         %__MODULE__{generation_by_wme: by_wme, generation_by_token: by_token} = rete,
         token
       ) do
    by_token = Map.delete(by_token, token)

    by_wme =
      case generated_wmes(rete, token) do
        nil ->
          by_wme

        wmes ->
          Enum.reduce(wmes, by_wme, fn wme, by_wme ->
            by_wme
            |> Map.update!(wme, &MapSet.delete(&1, token))
            |> delete_if(wme, &Enum.empty?/1)
          end)
      end

    %__MODULE__{
      rete
      | generation_by_wme: by_wme,
        generation_by_token: by_token
    }
  end

  defp delete_if(%{} = map, key, predicate) do
    if predicate.(Map.get(map, key)) do
      Map.delete(map, key)
    else
      map
    end
  end
end
