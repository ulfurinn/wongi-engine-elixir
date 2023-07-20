defmodule Wongi.Engine.Beta.Assign do
  @type t() :: %__MODULE__{}
  defstruct [:ref, :parent_ref, :name, :value]

  def new(parent_ref, name, value) do
    %__MODULE__{
      ref: make_ref(),
      parent_ref: parent_ref,
      name: name,
      value: value
    }
  end

  def evaluate(fun_or_static, token, rete)
  def evaluate(fun, _, _) when is_function(fun, 0), do: fun.()
  def evaluate(fun, token, _) when is_function(fun, 1), do: fun.(token)
  def evaluate(fun, token, rete) when is_function(fun, 2), do: fun.(token, rete)
  def evaluate(value, _, _), do: value

  defimpl Wongi.Engine.Beta do
    alias Wongi.Engine.Beta.Common
    alias Wongi.Engine.Rete
    alias Wongi.Engine.Token

    def ref(%@for{ref: ref}), do: ref
    def parent_ref(%@for{parent_ref: parent_ref}), do: parent_ref

    def seed(%@for{name: name, value: value} = node, beta, rete) do
      tokens = Rete.tokens(rete, node)

      Enum.reduce(tokens, rete, fn token, rete ->
        assignments = %{name => @for.evaluate(value, token, rete)}
        Common.beta_activate([beta], &Token.new(&1, [token], nil, assignments), rete)
      end)
    end

    def equivalent?(%@for{name: name, value: value}, %@for{name: name, value: value}, _rete),
      do: true

    def equivalent?(_, _, _), do: false

    @spec alpha_activate(
            Wongi.Engine.Beta.Assign.t(),
            Wongi.Engine.WME.t(),
            Wongi.Engine.Rete.t()
          ) :: no_return()
    defdelegate alpha_activate(assign, alpha, rete), to: Wongi.Engine.Beta.NonAlphaListening

    @spec alpha_deactivate(
            Wongi.Engine.Beta.Assign.t(),
            Wongi.Engine.WME.t(),
            Wongi.Engine.Rete.t()
          ) :: no_return()
    defdelegate alpha_deactivate(assign, alpha, rete), to: Wongi.Engine.Beta.NonAlphaListening

    def beta_activate(%@for{name: name, value: value} = node, token, rete) do
      rete = Rete.add_token(rete, token)
      assignments = %{name => @for.evaluate(value, token, rete)}
      betas = Rete.beta_subscriptions(rete, node)
      Common.beta_activate(betas, &Token.new(&1, [token], nil, assignments), rete)
    end

    def beta_deactivate(node, token, rete) do
      rete =
        rete
        |> Rete.remove_token(token)

      rete
      |> Rete.beta_subscriptions(node)
      |> Common.beta_deactivate(token, rete)
    end
  end
end
