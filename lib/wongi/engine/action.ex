defprotocol Wongi.Engine.Action do
  @moduledoc false
  def execute(action, token, rete)
  def deexecute(action, token, rete)
end
