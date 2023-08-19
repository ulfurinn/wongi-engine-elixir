defprotocol Wongi.Engine.Action do
  @moduledoc false
  def execute(action, token, rete)
  def deexecute(action, token, rete)
end

defimpl Wongi.Engine.Action, for: Function do
  alias Wongi.Engine.Rete

  def execute(fun, token, rete) when is_function(fun, 2) do
    case fun.(token, rete) do
      %Rete{} = updated -> updated
      _ -> rete
    end
  end

  def deexecute(_fun, _token, rete) do
    rete
  end
end
