defmodule Wongi.Engine.Filter.Function do
  @moduledoc false
  alias Wongi.Engine.DSL.Var

  defstruct [:var, :func]

  def new(func) do
    %__MODULE__{func: func}
  end

  def new(%Var{} = var, func) do
    %__MODULE__{var: var, func: func}
  end

  # A bare atom names a variable, as in aggregate's options. Taken as a literal,
  # it would be passed to the function as is, which is never what was meant.
  def new(name, func) when is_atom(name) and name not in [nil, true, false] do
    new(Var.new(name), func)
  end

  def new(value, _func) do
    raise ArgumentError,
          "filter/2 expects a variable, as var(:name) or :name, got: #{inspect(value)}"
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
