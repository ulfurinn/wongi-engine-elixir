defmodule Wongi.Engine.Filter.Function do
  @moduledoc false
  defstruct [:func]

  def new(func) do
    %__MODULE__{func: func}
  end

  defimpl Wongi.Engine.Filter do
    def pass?(%@for{func: func}, _token) when is_function(func, 0) do
      func.()
    end

    def pass?(%@for{func: func}, token) when is_function(func, 1) do
      func.(token)
    end
  end
end
