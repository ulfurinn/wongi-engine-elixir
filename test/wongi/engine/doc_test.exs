defmodule Wongi.Engine.DocTest do
  use Wongi.TestCase

  test "gen example" do
    rule =
      rule(
        forall: [
          has(var(:planet), :satellite, var(:satellite)),
          has(var(:planet), :mass, var(:planet_mass)),
          has(var(:satellite), :mass, var(:sat_mass)),
          has(var(:satellite), :distance, var(:distance)),
          assign(
            :pull,
            &(6.674e-11 * &1[:sat_mass] * &1[:planet_mass] / :math.pow(&1[:distance], 2))
          )
        ],
        do: [
          gen(var(:satellite), :pull, var(:pull))
        ]
      )

    engine =
      new()
      |> compile(rule)
      |> assert(:earth, :satellite, :moon)
      |> assert(:earth, :mass, 5.972e24)
      |> assert(:moon, :mass, 7.347_673_09e22)
      |> assert(:moon, :distance, 384_400.0e3)

    assert [wme] = engine |> select(:moon, :pull, :_) |> Enum.to_list()
    assert wme.object == 1.981_933_456_645_040_7e20
  end
end
