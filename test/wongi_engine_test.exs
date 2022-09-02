defmodule WongiEngineTest do
  use ExUnit.Case
  doctest WongiEngine

  test "greets the world" do
    assert WongiEngine.hello() == :world
  end
end
