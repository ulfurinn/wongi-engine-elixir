defmodule Wongi.Engine.GenerationTracker do
  @moduledoc false
  alias Wongi.Engine.Token
  alias Wongi.Engine.WME
  defstruct [:by_wme, :by_token]

  def new do
    %__MODULE__{
      by_wme: %{},
      by_token: %{}
    }
  end

  def add(%__MODULE__{by_wme: by_wme, by_token: by_token}, wme, token) do
    by_wme =
      by_wme
      |> Map.put_new_lazy(wme, &MapSet.new/0)
      |> Map.update!(wme, &MapSet.put(&1, token))

    by_token =
      by_token
      |> Map.put_new_lazy(token, &MapSet.new/0)
      |> Map.update!(token, &MapSet.put(&1, wme))

    %__MODULE__{
      by_wme: by_wme,
      by_token: by_token
    }
  end

  def get(%__MODULE__{by_wme: by_wme}, %WME{} = wme) do
    Map.get_lazy(by_wme, wme, &MapSet.new/0)
  end

  def get(%__MODULE__{by_token: by_token}, %Token{} = token) do
    Map.get_lazy(by_token, token, &MapSet.new/0)
  end

  def empty?(%__MODULE__{by_wme: by_wme}, %WME{} = wme) do
    not Map.has_key?(by_wme, wme)
  end

  def empty?(%__MODULE__{by_token: by_token}, %Token{} = token) do
    not Map.has_key?(by_token, token)
  end

  def remove(%__MODULE__{by_wme: by_wme, by_token: by_token} = tracker, token) do
    wmes = get(tracker, token)
    by_token = Map.delete(by_token, token)

    by_wme =
      Enum.reduce(wmes, by_wme, fn wme, by_wme ->
        by_wme
        |> Map.update!(wme, &MapSet.delete(&1, token))
        |> delete_if(wme, &Enum.empty?/1)
      end)

    %__MODULE__{
      by_wme: by_wme,
      by_token: by_token
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
