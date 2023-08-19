defmodule Wongi.Engine.ActionTest do
  use Wongi.TestCase

  test "using a function as an action" do
    _rete =
      new()
      |> compile(
        rule(
          forall: [
            has(:a, :b, var(:x))
          ],
          do: [
            fn token, _rete -> send(self(), {:action, token[:x]}) end
          ]
        )
      )
      |> assert(:a, :b, 1)

    assert_received {:action, 1}
  end
end
