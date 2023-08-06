defmodule Wongi.Engine.NCCTest do
  use Wongi.TestCase

  test "passes when the subchain does not pass" do
    {rete, ref} =
      new()
      |> compile_and_get_ref(
        rule(
          forall: [
            has(:base, :is, var(:base)),
            ncc([
              has(var(:base), :b, var(:x)),
              has(var(:x), :y, :z)
            ]),
            has(var(:base), :u, :v)
          ]
        )
      )

    initial = rete

    rete =
      rete
      |> assert(:base, :is, :a)
      |> assert(:a, :u, :v)

    assert [token] = rete |> tokens(ref) |> MapSet.to_list()
    assert :a = token[:base]

    rete =
      rete
      |> assert(:a, :b, :x)
      |> assert(:x, :y, :z)

    assert [] = rete |> tokens(ref) |> MapSet.to_list()

    rete =
      rete
      |> retract(:x, :y, :z)

    assert [_token] = rete |> tokens(ref) |> MapSet.to_list()

    # complete cleanup
    rete =
      rete
      |> retract(:a, :b, :x)
      |> retract(:base, :is, :a)
      |> retract(:a, :u, :v)

    assert initial == rete
  end

  test "complex example" do
    rete =
      new()
      |> compile(
        rule(
          forall: [
            has(:light_kitchen, :on, true)
          ],
          do: [
            gen(:automatic, :light_bathroom, true),
            gen(:automatic, :want_action_for, :light_bathroom)
          ]
        )
      )
      |> compile(
        rule(
          forall: [
            has(var(:requestor), :want_action_for, var(:device)),
            has(var(:requestor), var(:device), var(:state)),
            has(var(:requestor), :priority, var(:priority)),
            ncc([
              has(var(:other_requestor), :want_action_for, var(:device)),
              diff(var(:other_requestor), var(:requestor)),
              has(var(:other_requestor), :priority, var(:other_priority)),
              greater(var(:other_priority), var(:priority))
            ])
          ],
          do: [
            gen(var(:device), :on, var(:state)),
            gen(var(:device), :last_user, var(:requestor))
          ]
        )
      )

    rete =
      rete
      |> assert(:user, :priority, 1)
      |> assert(:automatic, :priority, 2)
      |> assert(:poweruser, :priority, 3)

    initial = rete

    rete =
      rete
      |> assert(:user, :want_action_for, :light_bathroom)
      |> assert(:user, :light_bathroom, false)

    assert false == get(rete, :light_bathroom, :on, :_).object
    assert :user == get(rete, :light_bathroom, :last_user, :_).object

    rete =
      rete
      |> assert(:light_kitchen, :on, true)

    assert true == get(rete, :light_bathroom, :on, :_).object
    assert :automatic == get(rete, :light_bathroom, :last_user, :_).object

    rete =
      rete
      |> assert(:poweruser, :want_action_for, :light_bathroom)
      |> assert(:poweruser, :light_bathroom, false)

    assert false == get(rete, :light_bathroom, :on, :_).object
    assert :poweruser == get(rete, :light_bathroom, :last_user, :_).object

    rete =
      rete
      |> retract(:poweruser, :want_action_for, :light_bathroom)
      |> retract(:poweruser, :light_bathroom, false)

    assert true == get(rete, :light_bathroom, :on, :_).object
    assert :automatic == get(rete, :light_bathroom, :last_user, :_).object

    rete =
      rete
      |> retract(:light_kitchen, :on, true)

    assert false == get(rete, :light_bathroom, :on, :_).object
    assert :user == get(rete, :light_bathroom, :last_user, :_).object

    rete =
      rete
      |> retract(:user, :want_action_for, :light_bathroom)
      |> retract(:user, :light_bathroom, false)

    assert initial == rete
  end

  defp get(rete, s, p, o) do
    [wme] = rete |> find(s, p, o) |> Enum.to_list()
    wme
  end
end
