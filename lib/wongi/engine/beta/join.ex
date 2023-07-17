# credo:disable-for-this-file Credo.Check.Refactor.Nesting
defmodule Wongi.Engine.Beta.Join do
  @moduledoc false
  alias Wongi.Engine.Beta
  alias Wongi.Engine.Token
  alias Wongi.Engine.WME

  @derive Inspect
  defstruct [:ref, :parent_ref, :template, :tests, :assignments]

  def new(parent_ref, template, tests, assignments) do
    %__MODULE__{
      ref: make_ref(),
      parent_ref: parent_ref,
      template: template,
      tests: tests,
      assignments: assignments
    }
  end

  def match(%__MODULE__{tests: tests, assignments: assignments}, token, wme) do
    [:subject, :predicate, :object]
    |> Enum.reduce_while({:ok, assignments}, fn field, {:ok, new_assignments} ->
      case Map.fetch(tests, field) do
        {:ok, var} ->
          value = wme[field]

          case Token.fetch(token, var, new_assignments) do
            {:ok, ^value} ->
              {:cont, {:ok, assign(new_assignments, field, value, assignments)}}

            _ ->
              {:halt, :error}
          end

        :error ->
          {:cont, {:ok, assign(new_assignments, field, wme, assignments)}}
      end
    end)
  end

  defp assign(acc, field, %WME{} = wme, assignment_decls) do
    assign(acc, field, wme[field], assignment_decls)
  end

  defp assign(acc, field, value, assignment_decls) do
    case Map.fetch(assignment_decls, field) do
      {:ok, var} ->
        Map.put(acc, var, value)

      :error ->
        acc
    end
  end

  def specialize(%__MODULE__{template: template, tests: tests}, token) do
    tests
    |> Enum.reduce(template, fn {field, var}, template ->
      case Token.fetch(token, var) do
        {:ok, value} ->
          Map.put(template, field, value)

        :error ->
          template
      end
    end)
  end

  defimpl Beta do
    alias Wongi.Engine.Beta.Common
    alias Wongi.Engine.Rete
    require Logger

    def ref(%@for{ref: ref}) do
      ref
    end

    def parent_ref(%@for{parent_ref: parent_ref}) do
      parent_ref
    end

    def seed(%@for{template: template} = join, beta, rete) do
      wmes = Rete.find(rete, template)
      tokens = Rete.tokens(rete, join)

      Enum.reduce(wmes, rete, fn wme, rete ->
        Enum.reduce(tokens, rete, &propagate_matching(join, &1, wme, [beta], &2))
      end)
    end

    def equivalent?(
          %@for{parent_ref: r, template: t, tests: ts, assignments: a},
          %@for{parent_ref: r, template: t, tests: ts, assignments: a},
          _rete
        ),
        do: true

    def equivalent?(_, _, _), do: false

    def alpha_activate(join, wme, rete) do
      Logger.debug("alpha activate #{inspect(join)} with #{inspect(wme)}")

      betas = Rete.beta_subscriptions(rete, join)
      tokens = Rete.tokens(rete, join)
      Enum.reduce(tokens, rete, &propagate_matching(join, &1, wme, betas, &2))
    end

    def alpha_deactivate(%@for{} = join, wme, rete) do
      rete
      |> Rete.beta_subscriptions(join)
      |> Common.beta_deactivate(wme, rete)
    end

    def beta_activate(%@for{} = join, token, rete) do
      # Logger.debug("beta activate #{inspect(join)} with #{inspect(token)}")
      # return early if already has a duplicate token?
      # is it possible or some artifact of the ruby impl?
      rete = Rete.add_token(rete, token)
      betas = Rete.beta_subscriptions(rete, join)
      wmes = Rete.find(rete, @for.specialize(join, token))

      Enum.reduce(wmes, rete, &propagate_matching(join, token, &1, betas, &2))
    end

    def beta_deactivate(join, token, rete) do
      rete =
      rete
      |> Rete.remove_token(token)

      rete
      |> Rete.beta_subscriptions(join)
      |> Common.beta_deactivate(token, rete)
    end

    defp propagate_matching(join, token, wme, betas, rete) do
      case @for.match(join, token, wme) do
        {:ok, assignments} ->
          Common.beta_activate(betas, &Token.new(&1, [token], wme, assignments), rete)

        _ ->
          rete
      end
    end
  end
end
