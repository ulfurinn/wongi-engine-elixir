defmodule WongiEngineTest do
  use ExUnit.Case
  doctest Wongi.Engine

  test "greets the world" do
    assert Wongi.Engine.hello() == :world
  end
end
