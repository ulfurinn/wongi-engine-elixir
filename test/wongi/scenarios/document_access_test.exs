defmodule Wongi.Scenarios.DocumentAccessTest do
  use Wongi.TestCase

  import Wongi.Scenario, only: [objects: 3, subjects: 3]

  alias Wongi.Scenario
  alias Wongi.Scenarios.DocumentAccess

  setup do
    rete =
      DocumentAccess
      |> Scenario.engine()
      |> Scenario.assert_all(for user <- DocumentAccess.users(), do: {user, :is, :user})
      |> Scenario.assert_all(for doc <- DocumentAccess.docs(), do: {doc, :is, :document})

    %{rete: rete}
  end

  test "a group grant reaches members of nested groups", %{rete: rete} do
    rete =
      Scenario.assert_all(rete, [
        {:bob, :member_of, :backend},
        {:backend, :part_of, :engineering},
        {:engineering, :grant_read, :roadmap}
      ])

    assert [:backend, :engineering] = objects(rete, :bob, :in_group)
    assert [:bob] = subjects(rete, :can_read, :roadmap)

    rete = retract(rete, :backend, :part_of, :engineering)

    assert [:backend] = objects(rete, :bob, :in_group)
    assert [] = subjects(rete, :can_read, :roadmap)
  end

  test "a folder grant covers documents in subfolders", %{rete: rete} do
    rete =
      Scenario.assert_all(rete, [
        {:runbook, :in_folder, :ops},
        {:ops, :in_folder, :shared},
        {:alice, :grant_read, :shared}
      ])

    assert [:ops, :shared] = objects(rete, :runbook, :located_in)
    assert [:runbook] = objects(rete, :alice, :can_read)
    assert [] = objects(rete, :alice, :can_write)
  end

  test "denial, suspension and archiving cut back access", %{rete: rete} do
    rete =
      Scenario.assert_all(rete, [
        {:runbook, :in_folder, :ops},
        {:carol, :grant_write, :ops}
      ])

    assert [:runbook] = objects(rete, :carol, :can_read)
    assert [:runbook] = objects(rete, :carol, :can_write)

    archived = assert(rete, :runbook, :archived, true)
    assert [:runbook] = objects(archived, :carol, :can_read)
    assert [] = objects(archived, :carol, :can_write)

    denied = assert(rete, :carol, :denied, :runbook)
    assert [] = objects(denied, :carol, :can_read)
    assert [] = objects(denied, :carol, :can_write)

    assert denied |> retract(:carol, :denied, :runbook) |> objects(:carol, :can_write) == [
             :runbook
           ]

    suspended = assert(rete, :carol, :suspended, true)
    assert [] = objects(suspended, :carol, :can_read)
  end

  test "losing one of two ways to access a document keeps the access", %{rete: rete} do
    rete =
      Scenario.assert_all(rete, [
        {:roadmap, :in_folder, :shared},
        {:carol, :grant_read, :shared},
        {:roadmap, :owner, :carol}
      ])

    assert [:roadmap] = objects(rete, :carol, :can_read)

    no_longer_owner = retract(rete, :roadmap, :owner, :carol)
    assert [:roadmap] = objects(no_longer_owner, :carol, :can_read)
    assert [] = objects(no_longer_owner, :carol, :can_write)

    no_longer_granted = retract(rete, :carol, :grant_read, :shared)
    assert [:roadmap] = objects(no_longer_granted, :carol, :can_read)
    assert [:roadmap] = objects(no_longer_granted, :carol, :can_write)

    neither = retract(no_longer_owner, :carol, :grant_read, :shared)
    assert [] = objects(neither, :carol, :can_read)
  end

  test "a write grant also grants read, whether or not that was granted too", %{rete: rete} do
    rete =
      Scenario.assert_all(rete, [
        {:dave, :grant_read, :payroll},
        {:dave, :grant_write, :payroll}
      ])

    assert [:payroll] = objects(rete, :dave, :can_read)

    assert rete |> retract(:dave, :grant_read, :payroll) |> objects(:dave, :can_read) == [
             :payroll
           ]

    assert rete |> retract(:dave, :grant_write, :payroll) |> objects(:dave, :can_read) == [
             :payroll
           ]
  end

  test "reports on how widely documents are shared", %{rete: rete} do
    rete =
      Scenario.assert_all(rete, [
        {:payroll, :owner, :alice},
        {:everyone, :grant_read, :payroll},
        {:bob, :member_of, :everyone},
        {:carol, :member_of, :everyone},
        {:roadmap, :owner, :dave},
        {:backend, :grant_read, :roadmap}
      ])

    assert [3] = objects(rete, :payroll, :reader_count)
    assert [true] = objects(rete, :payroll, :widely_shared)
    assert [] = objects(rete, :payroll, :private)

    # only its owner can read it, and the group it is granted to is empty
    assert [true] = objects(rete, :roadmap, :private)
    assert [:roadmap] = objects(rete, :backend, :unused_grant)
    assert [] = objects(rete, :everyone, :unused_grant)

    # nobody at all can read it
    assert [:runbook] = subjects(rete, :orphaned, true)

    rete = assert(rete, :bob, :suspended, true)
    assert [2] = objects(rete, :payroll, :reader_count)
    assert [] = objects(rete, :payroll, :widely_shared)

    rete = assert(rete, :bob, :member_of, :backend)
    assert [:roadmap] = objects(rete, :backend, :unused_grant)

    rete = retract(rete, :bob, :suspended, true)
    assert [] = objects(rete, :backend, :unused_grant)
    assert [] = objects(rete, :roadmap, :private)
  end
end
