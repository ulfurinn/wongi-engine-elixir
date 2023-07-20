defprotocol Wongi.Engine.Filter do
  @spec pass?(t, Wongi.Engine.Token.t()) :: boolean()
  def pass?(filter, token)
end

defmodule Wongi.Engine.Filter.Common do
  alias Wongi.Engine.DSL.Var
  def resolve(%Var{name: name}, token), do: token[name]
  def resolve(literal, _), do: literal
end
