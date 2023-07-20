defmodule Wongi.Engine.Rete do
  @moduledoc false
  import Wongi.Engine.WME, only: [root?: 1, template?: 1]

  alias Wongi.Engine.Beta
  alias Wongi.Engine.Beta.Root
  alias Wongi.Engine.Compiler
  alias Wongi.Engine.Overlay
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

  @type t() :: %__MODULE__{}

  @derive {Inspect, except: [:op_queue]}
  defstruct [
    :overlay,
    :alpha_subscriptions,
    :beta_root,
    :beta_table,
    :beta_subscriptions,
    :productions,
    :op_queue,
    :processing
  ]

  def new do
    root = Root.new()

    %__MODULE__{
      overlay: Overlay.new(),
      alpha_subscriptions: %{},
      beta_root: root,
      beta_table: %{Beta.ref(root) => root},
      beta_subscriptions: %{},
      productions: MapSet.new(),
      op_queue: :queue.new(),
      processing: false
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
    |> trigger({:assert, wme, generator})
  end

  def assert(rete, {s, p, o}, generator),
    do: assert(rete, WME.new(s, p, o), generator)

  def assert(rete, subject, object, predicate, generator \\ nil)

  def assert(rete, s, p, o, generator),
    do: assert(rete, WME.new(s, p, o), generator)

  def retract(rete, wme_ish, generator \\ nil)

  def retract(rete, %WME{} = wme, generator) do
    rete
    |> trigger({:retract, wme, generator})
  end

  def retract(rete, {s, p, o}, generator),
    do: retract(rete, WME.new(s, p, o), generator)

  def retract(rete, subject, object, predicate, generator \\ nil)

  def retract(rete, s, p, o, generator),
    do: retract(rete, WME.new(s, p, o), generator)

  def find(%__MODULE__{overlay: overlay}, %WME{} = wme) when not template?(wme) do
    if Overlay.has_wme?(overlay, wme) do
      MapSet.new([wme])
    else
      MapSet.new()
    end
  end

  def find(%__MODULE__{overlay: overlay}, %WME{} = wme) when root?(wme) do
    overlay
    |> Overlay.wmes()
  end

  def find(%__MODULE__{overlay: overlay}, %WME{} = wme) do
    overlay
    |> Overlay.matching(wme)
  end

  def find(rete, {s, p, o}),
    do: find(rete, WME.new(s, p, o))

  def find(rete, s, p, o),
    do: find(rete, WME.new(s, p, o))

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
    rete
    |> put_beta_table(Map.put(beta_table, Beta.ref(node), node))
    |> subscribe_to_beta(Beta.parent_ref(node), Beta.ref(node))
  end

  def subscribe_to_beta(%__MODULE__{beta_subscriptions: beta_subscriptions} = rete, parent, child)
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

  def trigger(%__MODULE__{op_queue: op_queue, processing: processing} = rete, operation) do
    rete =
      rete
      |> put_op_queue(:queue.in(operation, op_queue))

    if processing do
      rete
    else
      rete
      |> run_op_queue()
    end
  end

  defp run_op_queue(%__MODULE__{op_queue: op_queue} = rete) do
    case :queue.out(op_queue) do
      {{:value, operation}, op_queue} ->
        rete
        |> put_op_queue(op_queue)
        |> put_processing(true)
        |> handle_operation(operation)
        |> put_processing(false)
        |> run_op_queue()

      {:empty, op_queue} ->
        rete
        |> put_op_queue(op_queue)
    end
  end

  defp handle_operation(rete, {:assert, wme, generator}) do
    rete
    |> do_assert(wme, generator)
  end

  defp handle_operation(rete, {:retract, wme, generator}) do
    rete
    |> do_retract(wme, generator)
  end

  defp do_assert(%__MODULE__{overlay: overlay} = rete, wme, generator) do
    rete
    |> store_wme(wme, generator)
    |> activate(wme, Overlay.has_wme?(overlay, wme))
  end

  defp do_retract(%__MODULE__{overlay: overlay} = rete, wme, generator) do
    rete
    |> remove_wme(wme, generator)
    |> deactivate(wme, Overlay.has_wme?(overlay, wme))
  end

  defp store_wme(%__MODULE__{overlay: overlay} = rete, wme, generator) do
    rete
    |> put_overlay(Overlay.add_wme(overlay, wme, generator))
  end

  defp remove_wme(%__MODULE__{overlay: overlay} = rete, wme, generator) do
    rete
    |> put_overlay(Overlay.remove_wme(overlay, wme, generator))
  end

  defp activate(rete, wme, existing)
  defp activate(rete, _, true), do: rete

  defp activate(rete, wme, false) do
    subscriptions =
      rete
      |> alpha_subscriptions(wme)

    subscriptions |> Enum.reduce(rete, &Beta.alpha_activate(&1, wme, &2))
  end

  defp deactivate(rete, wme, existing)

  defp deactivate(rete, _, false), do: rete

  defp deactivate(rete, wme, true) do
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

  @spec add_token(Wongi.Engine.Rete.t(), Wongi.Engine.Token.t()) ::
          Wongi.Engine.Rete.t()
  def add_token(%__MODULE__{overlay: overlay} = rete, token) do
    rete
    |> put_overlay(Overlay.add_token(overlay, token))
  end

  def remove_token(%__MODULE__{overlay: overlay} = rete, token) do
    wmes = Overlay.generated_wmes(overlay, token)

    rete =
      rete
      |> put_overlay(Overlay.remove_token(overlay, token))

    wmes
    |> Enum.reduce(rete, &retract(&2, &1, token))
  end

  def tokens(%__MODULE__{overlay: overlay}, node) do
    Overlay.tokens(overlay, node)
  end

  def add_neg_join_result(%__MODULE__{overlay: overlay} = rete, token, wme) do
    rete
    |> put_overlay(Overlay.add_neg_join_result(overlay, token, wme))
  end

  def remove_neg_join_result(%__MODULE__{overlay: overlay} = rete, token, wme) do
    rete
    |> put_overlay(Overlay.remove_neg_join_result(overlay, token, wme))
  end

  def neg_join_results(%__MODULE__{overlay: overlay}, token_or_wme) do
    Overlay.neg_join_results(overlay, token_or_wme)
  end

  defp add_production(%__MODULE__{productions: productions} = rete, ref) do
    rete
    |> put_productions(MapSet.put(productions, ref))
  end

  def productions(%__MODULE__{productions: productions}), do: productions

  defp put_op_queue(%__MODULE__{} = rete, op_queue) do
    %__MODULE__{rete | op_queue: op_queue}
  end

  defp put_processing(%__MODULE__{} = rete, processing) do
    %__MODULE__{rete | processing: processing}
  end

  defp put_overlay(%__MODULE__{} = rete, overlay) do
    %__MODULE__{rete | overlay: overlay}
  end

  defp put_beta_table(%__MODULE__{} = rete, beta_table) do
    %__MODULE__{rete | beta_table: beta_table}
  end

  defp put_beta_subscriptions(%__MODULE__{} = rete, beta_subscriptions) do
    %__MODULE__{rete | beta_subscriptions: beta_subscriptions}
  end

  defp put_productions(%__MODULE__{} = rete, productions) do
    %__MODULE__{rete | productions: productions}
  end
end
