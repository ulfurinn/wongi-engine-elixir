defmodule Wongi.Engine.Filter.Function do
  @moduledoc false
  defstruct [:var, :func]

  def new(func) do
    %__MODULE__{func: func}
  end

  def new(var, func) do
    %__MODULE__{var: var, func: func}
  end

  defimpl Wongi.Engine.Filter do
    alias Wongi.Engine.Filter.Common

    def pass?(%@for{var: nil, func: func}, _token) when is_function(func, 0) do
      func.()
    end

    def pass?(%@for{var: nil, func: func}, token) when is_function(func, 1) do
      func.(token)
    end

    def pass?(%@for{var: var, func: func}, token) when is_function(func, 1) do
      func.(Common.resolve(var, token))
    end
  end
end
