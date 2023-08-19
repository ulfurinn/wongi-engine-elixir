defmodule Wongi.TestCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  using do
    quote do
      use Wongi.Engine.DSL

      import Wongi.Engine

      alias Wongi.Engine
      alias Wongi.Engine.Token
      alias Wongi.Engine.WME
    end
  end
end
