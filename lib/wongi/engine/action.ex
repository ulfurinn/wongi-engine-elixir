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

  def execute(fun, token, rete) when is_function(fun, 3) do
    case fun.(:execute, token, rete) do
      %Rete{} = updated -> updated
      _ -> rete
    end
  end

  def deexecute(fun, _, rete) when is_function(fun, 2) do
    rete
  end

  def deexecute(fun, token, rete) when is_function(fun, 3) do
    case fun.(:deexecute, token, rete) do
      %Rete{} = updated -> updated
      _ -> rete
    end
  end
end
