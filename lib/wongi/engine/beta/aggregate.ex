defmodule Wongi.Engine.Beta.Aggregate do
  @moduledoc false
  alias Wongi.Engine.Beta
  alias Wongi.Engine.Beta.Common
  alias Wongi.Engine.Rete
  alias Wongi.Engine.Token

  @type t() :: %__MODULE__{}
  defstruct [:ref, :parent_ref, :var, :fun, :partition, :mapper, opts: []]

  def new(parent_ref, var, fun, opts) do
    mapper =
      case opts[:map] do
        nil ->
          over = Keyword.fetch!(opts, :over)
          & &1[over]

        fun ->
          fun
      end

    partition =
      case opts[:partition] do
        nil ->
          nil

        var when is_atom(var) ->
          & &1[var]

        vars when is_list(vars) ->
          &Enum.map(vars, fn var -> &1[var] end)
      end

    %__MODULE__{
      ref: make_ref(),
      parent_ref: parent_ref,
      var: var,
      fun: fun,
      partition: partition,
      mapper: mapper,
      opts: opts
    }
  end

  def evaluate(node, node_action, token, rete) do
    evaluate(node, node_action, token, Rete.beta_subscriptions(rete, node), rete)
  end

  def evaluate(node, node_action, token, child, rete) when not is_list(child) do
    evaluate(node, node_action, token, [child], rete)
  end

  def evaluate(node, :seed, nil, betas, rete) do
    partition = partition_fn(node)

    groups =
      if partition do
        Enum.group_by(Rete.tokens(rete, node), partition)
        |> Map.values()
      else
        [Rete.tokens(rete, node)]
      end

    Enum.reduce(groups, rete, &evaluate_partition(node, betas, &1, &2))
  end

  def evaluate(node, :activate, token, betas, rete) do
    partition = partition_fn(node)

    token_partition = if partition, do: partition.(token)

    rete =
      rete
      |> Rete.add_token(token)
      |> Rete.put_node_index(node, token_partition, token)

    evaluate_changed_partition(node, token_partition, partition, betas, rete)
  end

  def evaluate(node, :deactivate, token, betas, rete) do
    partition = partition_fn(node)

    token_partition = if partition, do: partition.(token)

    rete =
      rete
      |> Rete.remove_token(token)
      |> Rete.delete_node_index(node, token_partition, token)

    rete = Common.beta_deactivate(Rete.beta_subscriptions(rete, node), token, rete)

    evaluate_changed_partition(node, token_partition, partition, betas, rete)
  end

  # Tokens are also stored by partition value (nil, when not partitioned, is not
  # indexed), so a change only has to re-aggregate the partition it belongs to.
  defp evaluate_changed_partition(node, token_partition, _partition_f, betas, rete) do
    group =
      if token_partition do
        Rete.get_node_index(rete, node, token_partition)
      else
        Rete.tokens(rete, node)
      end

    evaluate_partition(node, betas, group, rete)
  end

  defp evaluate_partition(node, betas, tokens, rete) do
    if Enum.empty?(tokens) do
      rete
    else
      aggregator = aggregator_fn(node)
      mapper = mapper_fn(node)

      mapped = Enum.map(tokens, mapper)
      aggregated = mapped |> aggregator.()
      assignment = Map.put(inherited_assignments(tokens), node.var, aggregated)

      Enum.reduce(betas, rete, fn beta, rete ->
        new_token = Token.new(beta, tokens, nil, assignment)

        rete =
          tokens
          |> Enum.flat_map(&Enum.to_list(Rete.child_tokens(rete, beta, &1)))
          |> Enum.uniq()
          |> Enum.reduce(rete, &Beta.beta_deactivate(beta, &1, &2))

        Beta.beta_activate(beta, new_token, rete)
      end)
    end
  end

  # The aggregated token has all tokens of the group as parents, which may bind
  # the same variable to different values. Left to the parent set's iteration
  # order, which variable value is visible downstream would depend on the
  # identity of the tokens, so resolve it here in a way that depends only on
  # their contents.
  defp inherited_assignments(tokens) do
    tokens
    |> Enum.map(&Token.assignments/1)
    |> Enum.sort()
    |> Enum.reduce(%{}, &Map.merge(&2, &1))
  end

  def aggregator_fn(%__MODULE__{fun: fun}), do: fun
  def partition_fn(%__MODULE__{partition: partition}), do: partition
  def mapper_fn(%__MODULE__{mapper: mapper}), do: mapper

  defimpl Wongi.Engine.Beta do
    def ref(%@for{ref: ref}), do: ref
    def parent_refs(%@for{parent_ref: parent_ref}), do: [parent_ref]

    def equivalent?(
          %@for{var: var, fun: fun, opts: opts1},
          %@for{var: var, fun: fun, opts: opts2},
          _rete
        ),
        do: Keyword.equal?(opts1, opts2)

    def equivalent?(_, _, _), do: false

    def seed(node, beta, rete) do
      @for.evaluate(node, :seed, nil, beta, rete)
    end

    @spec alpha_activate(
            Wongi.Engine.Beta.Aggregate.t(),
            Wongi.Engine.WME.t(),
            Wongi.Engine.Rete.t()
          ) :: no_return()
    defdelegate alpha_activate(node, alpha, rete), to: Wongi.Engine.Beta.NonAlphaListening

    @spec alpha_deactivate(
            Wongi.Engine.Beta.Aggregate.t(),
            Wongi.Engine.WME.t(),
            Wongi.Engine.Rete.t()
          ) :: no_return()
    defdelegate alpha_deactivate(node, alpha, rete), to: Wongi.Engine.Beta.NonAlphaListening

    def beta_activate(node, token, rete) do
      @for.evaluate(node, :activate, token, rete)
    end

    def beta_deactivate(node, token, rete) do
      @for.evaluate(node, :deactivate, token, rete)
    end
  end
end
