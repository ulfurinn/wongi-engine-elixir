defprotocol Wongi.Engine.Filter do
  @moduledoc false
  @spec pass?(t, Wongi.Engine.Token.t()) :: boolean()
  def pass?(filter, token)
end

defmodule Wongi.Engine.Filter.Common do
  @moduledoc false
  alias Wongi.Engine.DSL.Var
  def resolve(%Var{name: name}, token), do: token[name]
  def resolve(literal, _), do: literal
end
