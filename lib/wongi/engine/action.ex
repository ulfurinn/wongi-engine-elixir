defprotocol Wongi.Engine.Action do
  def execute(action, token, rete)
  def deexecute(action, token, rete)
end
