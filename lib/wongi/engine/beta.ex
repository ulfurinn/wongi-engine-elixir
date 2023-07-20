defprotocol Wongi.Engine.Beta do
  @moduledoc false
  def ref(beta)
  def parent_ref(beta)
  def seed(beta, listener, rete)

  def equivalent?(beta, other, rete)

  def alpha_activate(listener, wme, rete)
  def alpha_deactivate(listener, wme, rete)

  def beta_activate(listener, token, rete)
  def beta_deactivate(listener, token, rete)
end

defimpl Wongi.Engine.Beta, for: Reference do
  alias Wongi.Engine.Beta
  alias Wongi.Engine.Rete

  def ref(ref), do: ref
  def parent_ref(_), do: raise("cannot fetch parent of bare ref")

  def equivalent?(ref, other, rete) do
    rete
    |> Rete.get_beta(ref)
    |> Beta.equivalent?(other, rete)
  end

  def seed(ref, listener, rete) do
    rete
    |> Rete.get_beta(ref)
    |> Wongi.Engine.Beta.seed(listener, rete)
  end

  def alpha_activate(ref, wme, rete) do
    rete
    |> Rete.get_beta(ref)
    |> Beta.alpha_activate(wme, rete)
  end

  def alpha_deactivate(ref, wme, rete) do
    rete
    |> Rete.get_beta(ref)
    |> Beta.alpha_deactivate(wme, rete)
  end

  def beta_activate(ref, token, rete) do
    rete
    |> Rete.get_beta(ref)
    |> Beta.beta_activate(token, rete)
  end

  def beta_deactivate(ref, token, rete) do
    rete
    |> Rete.get_beta(ref)
    |> Beta.beta_deactivate(token, rete)
  end
end

defmodule Wongi.Engine.Beta.Common do
  @moduledoc false
  alias Wongi.Engine.Beta
  alias Wongi.Engine.Rete
  alias Wongi.Engine.Token
  alias Wongi.Engine.WME

  def beta_activate(betas, token_ctor, rete) do
    Enum.reduce(betas, rete, fn beta, rete ->
      Beta.beta_activate(beta, token_ctor.(beta), rete)
    end)
  end

  def beta_deactivate(betas, %Token{} = token, rete) do
    Enum.reduce(betas, rete, fn beta, rete ->
      rete
      |> Rete.tokens(beta)
      |> Enum.filter(&Token.child_of?(&1, token))
      |> Enum.reduce(rete, fn token, rete ->
        Beta.beta_deactivate(beta, token, rete)
      end)
    end)
  end

  def beta_deactivate(betas, %WME{} = wme, rete) do
    Enum.reduce(betas, rete, fn beta, rete ->
      rete
      |> Rete.tokens(beta)
      |> Enum.filter(&Token.has_wme?(&1, wme))
      |> Enum.reduce(rete, fn token, rete ->
        Beta.beta_deactivate(beta, token, rete)
      end)
    end)
  end
end

defmodule Wongi.Engine.Beta.NonAlphaListening do
  @moduledoc false
  def alpha_activate(%mod{}, _, _), do: raise("#{mod} cannot be alpha-activated")
  def alpha_deactivate(%mod{}, _, _), do: raise("#{mod} cannot be alpha-deactivated")
end
