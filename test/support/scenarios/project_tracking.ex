defmodule Wongi.Scenarios.ProjectTracking do
  @moduledoc false
  # Tasks, dependencies and people in a project tracker.
  #
  # Tasks belong to projects, are assigned to people, and may depend on other
  # tasks. People report to managers and may be on leave. The rules find
  # blocked and overdue work, escalate it up the reporting chain, and summarise
  # the state of each project.
  #
  # Input facts:
  #
  #   {task, :project, project}        {task, :assignee, person}
  #   {task, :status, status}          {task, :depends_on, task}
  #   {task, :due, day}                {task, :estimate, hours}
  #   {:calendar, :today, day}         {person, :is, :person}
  #   {person, :reports_to, person}    {person, :on_leave, true}
  #   {project, :is, :project}         {project, :lead, person}
  #
  # where status is :todo, :doing or :done. Dependencies and reporting lines
  # are not required to be acyclic, and finding cycles is one of the rules.
  @behaviour Wongi.Scenario

  use Wongi.Engine.DSL
  import Wongi.Scenario, only: [triple: 3]

  @tasks [:design, :build, :test, :launch]
  @projects [:website, :app]
  @people [:grace, :heidi, :ivan]

  @impl Wongi.Scenario
  def rules do
    [
      # Dependencies, direct and indirect.
      rule(:direct_dependency,
        forall: [has(var(:task), :depends_on, var(:other))],
        do: [gen(var(:task), :after, var(:other))]
      ),
      rule(:indirect_dependency,
        forall: [
          has(var(:task), :after, var(:other)),
          has(var(:other), :depends_on, var(:further))
        ],
        do: [gen(var(:task), :after, var(:further))]
      ),
      # A task that comes after itself can never start. The variable repeats
      # within one clause.
      rule(:dependency_cycle,
        forall: [has(var(:task), :after, var(:task))],
        do: [gen(var(:task), :in_cycle, true)]
      ),

      # A task is blocked by any dependency that is not done yet.
      rule(:blocked,
        forall: [
          has(var(:task), :depends_on, var(:other)),
          neg(var(:other), :status, :done)
        ],
        do: [gen(var(:task), :blocked_by, var(:other))]
      ),
      rule(:ready,
        forall: [
          has(var(:task), :status, :todo),
          neg(var(:task), :blocked_by, :_),
          has(var(:task), :assignee, var(:person)),
          neg(var(:person), :on_leave, true)
        ],
        do: [gen(var(:task), :ready, true)]
      ),
      rule(:overdue,
        forall: [
          has(:calendar, :today, var(:today)),
          has(var(:task), :due, var(:due)),
          less(var(:due), var(:today)),
          neg(var(:task), :status, :done)
        ],
        do: [gen(var(:task), :overdue, true)]
      ),
      rule(:needs_reassignment,
        forall: [
          has(var(:task), :assignee, var(:person)),
          has(var(:person), :on_leave, true),
          neg(var(:task), :status, :done)
        ],
        do: [gen(var(:task), :needs_reassignment, true)]
      ),

      # The reporting chain, and escalation of overdue work up to the first
      # manager who is not on leave.
      rule(:direct_manager,
        forall: [has(var(:person), :reports_to, var(:manager))],
        do: [gen(var(:person), :managed_by, var(:manager))]
      ),
      rule(:indirect_manager,
        forall: [
          has(var(:person), :managed_by, var(:manager)),
          has(var(:manager), :reports_to, var(:boss))
        ],
        do: [gen(var(:person), :managed_by, var(:boss))]
      ),
      rule(:escalate,
        forall: [
          has(var(:task), :overdue, true),
          has(var(:task), :assignee, var(:person)),
          has(var(:person), :managed_by, var(:manager)),
          diff(var(:manager), var(:person)),
          neg(var(:manager), :on_leave, true)
        ],
        do: [gen(var(:manager), :escalated, var(:task))]
      ),

      # Workload, counting only unfinished work.
      rule(:workload,
        forall: [
          has(var(:task), :assignee, var(:person)),
          has(var(:task), :estimate, var(:hours)),
          neg(var(:task), :status, :done),
          aggregate(&sum/1, :workload, over: :hours, partition: :person)
        ],
        do: [gen(var(:person), :workload, var(:workload))]
      ),
      rule(:overloaded,
        forall: [
          has(var(:person), :workload, var(:hours)),
          greater(var(:hours), 40)
        ],
        do: [gen(var(:person), :overloaded, true)]
      ),
      rule(:idle,
        forall: [
          has(var(:person), :is, :person),
          neg(var(:person), :on_leave, true),
          ncc([
            has(var(:task), :assignee, var(:person)),
            has(var(:task), :status, :doing)
          ])
        ],
        do: [gen(var(:person), :idle, true)]
      ),
      rule(:estimated_days,
        forall: [
          has(var(:task), :estimate, var(:hours)),
          assign(:days, &div(&1[:hours] + 7, 8))
        ],
        do: [gen(var(:task), :estimated_days, var(:days))]
      ),

      # Project summaries.
      rule(:overdue_count,
        forall: [
          has(var(:task), :overdue, true),
          has(var(:task), :project, var(:project)),
          aggregate(&Enum.count/1, :count, over: :task, partition: :project)
        ],
        do: [gen(var(:project), :overdue_tasks, var(:count))]
      ),
      rule(:at_risk,
        forall: [
          has(var(:project), :is, :project),
          any([
            [has(var(:project), :overdue_tasks, var(:count)), gte(var(:count), 2)],
            [has(var(:project), :lead, var(:lead)), has(var(:lead), :on_leave, true)],
            [has(var(:task), :project, var(:project)), has(var(:task), :in_cycle, true)]
          ])
        ],
        do: [gen(var(:project), :at_risk, true)]
      ),
      # A project is complete when it has no task that is not done.
      rule(:complete,
        forall: [
          has(var(:project), :is, :project),
          ncc([
            has(var(:task), :project, var(:project)),
            neg(var(:task), :status, :done)
          ])
        ],
        do: [gen(var(:project), :complete, true)]
      )
    ]
  end

  @impl Wongi.Scenario
  def fact do
    StreamData.frequency([
      {3, triple(@tasks, :project, @projects)},
      {3, triple(@tasks, :assignee, @people)},
      {4, triple(@tasks, :status, [:todo, :doing, :done])},
      {3, triple(@tasks, :depends_on, @tasks)},
      {2, triple(@tasks, :due, [1, 2, 3])},
      {2, triple(@tasks, :estimate, [4, 16, 30])},
      {1, triple(:calendar, :today, [1, 2, 3])},
      {2, triple(@people, :is, :person)},
      {2, triple(@people, :reports_to, @people)},
      {1, triple(@people, :on_leave, true)},
      {1, triple(@projects, :is, :project)},
      {1, triple(@projects, :lead, @people)}
    ])
  end
end
