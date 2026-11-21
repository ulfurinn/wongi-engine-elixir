defmodule Wongi.Engine.Filter.Equal do
  @moduledoc false
  defstruct [:a, :b]

  def new(a, b) do
    %__MODULE__{a: a, b: b}
  end

  defimpl Wongi.Engine.Filter do
    alias Wongi.Engine.Compare
    alias Wongi.Engine.Filter.Common

    def pass?(%@for{a: a, b: b}, token) do
      Compare.compare(Common.resolve(a, token), Common.resolve(b, token)) == :eq
    end
  end
end
