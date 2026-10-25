defmodule Wongi.Scenarios.ProjectTrackingTest do
  use Wongi.TestCase

  import Wongi.Scenario, only: [objects: 3, subjects: 3]

  alias Wongi.Scenario
  alias Wongi.Scenarios.ProjectTracking

  setup do
    rete =
      ProjectTracking
      |> Scenario.engine()
      |> Scenario.assert_all([
        {:grace, :is, :person},
        {:heidi, :is, :person},
        {:ivan, :is, :person},
        {:ivan, :reports_to, :heidi},
        {:heidi, :reports_to, :grace},
        {:website, :is, :project}
      ])

    %{rete: rete}
  end

  test "dependencies block tasks until they are done", %{rete: rete} do
    rete =
      Scenario.assert_all(rete, [
        {:build, :depends_on, :design},
        {:test, :depends_on, :build},
        {:design, :status, :doing},
        {:build, :status, :todo},
        {:build, :assignee, :ivan}
      ])

    assert [:build, :design] = objects(rete, :test, :after)
    assert [:design] = objects(rete, :build, :blocked_by)
    assert [] = subjects(rete, :ready, true)

    rete = assert(rete, :design, :status, :done)
    assert [] = objects(rete, :build, :blocked_by)
    assert [:build] = subjects(rete, :ready, true)

    rete = assert(rete, :ivan, :on_leave, true)
    assert [] = subjects(rete, :ready, true)
    assert [:build] = subjects(rete, :needs_reassignment, true)
  end

  test "dependency cycles are found", %{rete: rete} do
    rete =
      Scenario.assert_all(rete, [
        {:build, :depends_on, :design},
        {:test, :depends_on, :build},
        {:launch, :depends_on, :test}
      ])

    assert [] = subjects(rete, :in_cycle, true)

    rete = assert(rete, :design, :depends_on, :test)
    assert [:build, :design, :test] = subjects(rete, :in_cycle, true)

    rete = retract(rete, :test, :depends_on, :build)
    assert [] = subjects(rete, :in_cycle, true)
    assert [:design, :test] = objects(rete, :build, :after)
  end

  test "overdue work is escalated to the first manager at work", %{rete: rete} do
    rete =
      Scenario.assert_all(rete, [
        {:calendar, :today, 3},
        {:build, :due, 2},
        {:build, :status, :doing},
        {:build, :assignee, :ivan}
      ])

    assert [:grace, :heidi] = objects(rete, :ivan, :managed_by)
    assert [true] = objects(rete, :build, :overdue)
    assert [:grace, :heidi] = subjects(rete, :escalated, :build)

    rete = assert(rete, :heidi, :on_leave, true)
    assert [:grace] = subjects(rete, :escalated, :build)

    rete = assert(rete, :build, :status, :done)
    assert [] = objects(rete, :build, :overdue)
    assert [] = subjects(rete, :escalated, :build)
  end

  test "workload counts unfinished work only", %{rete: rete} do
    rete =
      Scenario.assert_all(rete, [
        {:design, :assignee, :heidi},
        {:design, :estimate, 30},
        {:build, :assignee, :heidi},
        {:build, :estimate, 16},
        {:build, :status, :doing}
      ])

    assert [46] = objects(rete, :heidi, :workload)
    assert [true] = objects(rete, :heidi, :overloaded)
    assert [4] = objects(rete, :design, :estimated_days)
    assert [2] = objects(rete, :build, :estimated_days)

    # heidi has something in progress; the others do not
    assert [:grace, :ivan] = subjects(rete, :idle, true)

    rete = assert(rete, :design, :status, :done)
    assert [16] = objects(rete, :heidi, :workload)
    assert [] = objects(rete, :heidi, :overloaded)

    rete = rete |> retract(:build, :status, :doing) |> assert(:build, :status, :done)
    assert [] = objects(rete, :heidi, :workload)
    assert [:grace, :heidi, :ivan] = subjects(rete, :idle, true)
  end

  test "project summaries", %{rete: rete} do
    # a project with no tasks is trivially complete
    assert [true] = objects(rete, :website, :complete)

    rete =
      Scenario.assert_all(rete, [
        {:calendar, :today, 3},
        {:design, :project, :website},
        {:design, :due, 1},
        {:build, :project, :website},
        {:build, :due, 2}
      ])

    assert [] = objects(rete, :website, :complete)
    assert [2] = objects(rete, :website, :overdue_tasks)
    assert [true] = objects(rete, :website, :at_risk)

    rete = assert(rete, :design, :status, :done)
    assert [1] = objects(rete, :website, :overdue_tasks)
    assert [] = objects(rete, :website, :at_risk)

    rete = rete |> assert(:website, :lead, :heidi) |> assert(:heidi, :on_leave, true)
    assert [true] = objects(rete, :website, :at_risk)

    rete = rete |> retract(:heidi, :on_leave, true) |> assert(:build, :status, :done)
    assert [] = objects(rete, :website, :overdue_tasks)
    assert [] = objects(rete, :website, :at_risk)
    assert [true] = objects(rete, :website, :complete)
  end
end
