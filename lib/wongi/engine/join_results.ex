defmodule Wongi.Engine.JoinResults do
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
