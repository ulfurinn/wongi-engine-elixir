defmodule Wongi.TestCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  using do
    quote do
      import Wongi.Engine
      import Wongi.Engine.DSL

      alias Wongi.Engine
      alias Wongi.Engine.Token
      alias Wongi.Engine.WME
    end
  end
end
