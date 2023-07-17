# credo:disable-for-this-file Credo.Check.Refactor.Nesting
defmodule Wongi.Engine.Beta.Negative do
  @moduledoc false
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
    |> Enum.reduce_while({:ok, %{}}, fn field, {:ok, new_assignments} ->
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
    |> case do
      {:ok, _} -> true
      :error -> false
    end
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

  defimpl Wongi.Engine.Beta do
    alias Wongi.Engine.Beta
    alias Wongi.Engine.Beta.Common
    alias Wongi.Engine.Rete

    def ref(%@for{ref: ref}), do: ref
    def parent_ref(%@for{parent_ref: parent_ref}), do: parent_ref

    def seed(%@for{template: template} = neg, beta, rete) do
      tokens = Rete.tokens(rete, neg)
      wmes = Rete.find(rete, template)

      rete =
        Enum.reduce(tokens, rete, fn token, rete ->
          if Enum.empty?(Rete.neg_join_results(rete, token)) do
            Beta.beta_activate(beta, Token.new(beta, [token], nil), rete)
          else
            rete
          end
        end)

      Enum.reduce(wmes, rete, fn wme, rete ->
        alpha_activate(neg, wme, rete, betas: [beta])
      end)
    end

    def equivalent?(
          %@for{parent_ref: r, template: t, tests: ts},
          %@for{parent_ref: r, template: t, tests: ts},
          _rete
        ),
        do: true

    def equivalent?(_, _, _), do: false

    def alpha_activate(neg, wme, rete),
      do: alpha_activate(neg, wme, rete, betas: Rete.beta_subscriptions(rete, neg))

    defp alpha_activate(neg, wme, rete, betas: betas) do
      tokens = Rete.tokens(rete, neg)

      Enum.reduce(tokens, rete, fn token, rete ->
        if @for.match(neg, token, wme) do
          rete =
            rete
            |> Rete.add_neg_join_result(token, wme)

          Common.beta_deactivate(betas, token, rete)
        else
          rete
        end
      end)
    end

    def alpha_deactivate(neg, wme, rete) do
      Rete.neg_join_results(rete, wme)
      |> Enum.reduce(rete, fn {token, wme}, rete ->
        Rete.tokens(rete, neg)
        |> Enum.filter(fn t -> t == token end)
        |> Enum.reduce(rete, fn token, rete ->
          rete = Rete.remove_neg_join_result(rete, token, wme)

          if Enum.empty?(Rete.neg_join_results(rete, token)) do
            Rete.beta_subscriptions(rete, neg)
            |> Enum.reduce(rete, fn beta, rete ->
              Beta.beta_activate(beta, Token.new(beta, [token], nil), rete)
            end)
          else
            rete
          end
        end)
      end)
    end

    def beta_activate(neg, token, rete) do
      # return early if already has a duplicate token?
      # is it possible or some artifact of the ruby impl?
      rete = Rete.add_token(rete, token)
      wmes = Rete.find(rete, @for.specialize(neg, token))

      rete =
        Enum.reduce(wmes, rete, fn wme, rete ->
          if @for.match(neg, token, wme) do
            Rete.add_neg_join_result(rete, token, wme)
          else
            rete
          end
        end)

      if Enum.empty?(Rete.neg_join_results(rete, token)) do
        betas = Rete.beta_subscriptions(rete, neg)

        Enum.reduce(betas, rete, fn beta, rete ->
          Beta.beta_activate(beta, Token.new(beta, [token], nil), rete)
        end)
      else
        rete
      end
    end

    def beta_deactivate(neg, token, rete) do
      rete =
        rete
        |> Rete.remove_token(token)

      rete
      |> Rete.beta_subscriptions(neg)
      |> Common.beta_deactivate(token, rete)
    end
  end
end
