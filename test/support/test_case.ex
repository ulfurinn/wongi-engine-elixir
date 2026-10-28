defmodule Wongi.TestCase do
  @moduledoc false
  use ExUnit.CaseTemplate

  using do
    quote do
      use Wongi.Engine.DSL

      import Wongi.Engine, except: [new: 0, new: 1]

      alias Wongi.Engine
      alias Wongi.Engine.Token
      alias Wongi.Engine.WME

      def new, do: Wongi.Engine.new(Wongi.TestCase.engine_opts())
    end
  end

  # TOKEN_INDEXES=false mix test runs the suite without token indexes.
  def engine_opts do
    [token_indexes: System.get_env("TOKEN_INDEXES", "true") != "false"]
  end
end
