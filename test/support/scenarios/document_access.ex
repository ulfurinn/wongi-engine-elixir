defmodule Wongi.Scenarios.DocumentAccess do
  @moduledoc false
  # Who can read and edit which documents in a small company wiki.
  #
  # Users belong to groups, groups can be nested, documents live in nested
  # folders, and read or write access can be granted on a document or a folder,
  # to a user or a group. Effective access is then cut back by suspensions,
  # explicit denials and archiving.
  #
  # Input facts:
  #
  #   {user, :is, :user}               {doc, :is, :document}
  #   {user, :member_of, group}        {group, :part_of, group}
  #   {doc, :in_folder, folder}        {folder, :in_folder, folder}
  #   {principal, :grant_read, target} {principal, :grant_write, target}
  #   {doc, :owner, user}              {user, :denied, doc}
  #   {user, :suspended, true}         {doc, :archived, true}
  #
  # where a principal is a user or a group, and a target is a document or a
  # folder. Neither groups nor folders are required to form a tree; a cycle
  # simply makes its members equivalent.
  @behaviour Wongi.Scenario

  use Wongi.Engine.DSL
  import Wongi.Scenario, only: [triple: 3]

  @users [:alice, :bob, :carol, :dave]
  @groups [:engineering, :backend, :everyone]
  @docs [:roadmap, :payroll, :runbook]
  @folders [:shared, :ops, :hr]

  def users, do: @users
  def groups, do: @groups
  def docs, do: @docs
  def folders, do: @folders

  @impl Wongi.Scenario
  def rules do
    [
      # Group membership is transitive: a member of :backend, which is part of
      # :engineering, is also in :engineering.
      rule(:direct_membership,
        forall: [has(var(:user), :member_of, var(:group))],
        do: [gen(var(:user), :in_group, var(:group))]
      ),
      rule(:nested_membership,
        forall: [
          has(var(:user), :in_group, var(:group)),
          has(var(:group), :part_of, var(:outer))
        ],
        do: [gen(var(:user), :in_group, var(:outer))]
      ),

      # So is the location of a document: it is in its folder and in every
      # folder above that.
      rule(:direct_location,
        forall: [has(var(:doc), :in_folder, var(:folder))],
        do: [gen(var(:doc), :located_in, var(:folder))]
      ),
      rule(:nested_location,
        forall: [
          has(var(:doc), :located_in, var(:folder)),
          has(var(:folder), :in_folder, var(:outer))
        ],
        do: [gen(var(:doc), :located_in, var(:outer))]
      ),

      # Write access implies read access. This generates :grant_read facts that
      # may also have been asserted by hand.
      rule(:write_implies_read,
        forall: [has(var(:principal), :grant_write, var(:target))],
        do: [gen(var(:principal), :grant_read, var(:target))]
      ),

      # A grant to a group applies to every member.
      rule(:group_read,
        forall: [
          has(var(:user), :in_group, var(:group)),
          has(var(:group), :grant_read, var(:target))
        ],
        do: [gen(var(:user), :grant_read, var(:target))]
      ),
      rule(:group_write,
        forall: [
          has(var(:user), :in_group, var(:group)),
          has(var(:group), :grant_write, var(:target))
        ],
        do: [gen(var(:user), :grant_write, var(:target))]
      ),

      # A grant on a folder applies to every document in it. Documents are
      # granted to themselves to have a single rule for both cases.
      rule(:may_read,
        forall: [
          has(var(:user), :is, :user),
          has(var(:user), :grant_read, var(:target)),
          has(var(:doc), :is, :document),
          any([
            [equal(var(:doc), var(:target))],
            [has(var(:doc), :located_in, var(:target))]
          ])
        ],
        do: [gen(var(:user), :may_read, var(:doc))]
      ),
      rule(:may_write,
        forall: [
          has(var(:user), :is, :user),
          has(var(:user), :grant_write, var(:target)),
          has(var(:doc), :is, :document),
          any([
            [equal(var(:doc), var(:target))],
            [has(var(:doc), :located_in, var(:target))]
          ])
        ],
        do: [gen(var(:user), :may_write, var(:doc))]
      ),

      # Owners can always edit their documents, grants or not.
      rule(:owner_writes,
        forall: [
          has(var(:doc), :owner, var(:user)),
          has(var(:user), :is, :user),
          has(var(:doc), :is, :document)
        ],
        do: [gen(var(:user), :may_write, var(:doc))]
      ),
      rule(:writer_reads,
        forall: [has(var(:user), :may_write, var(:doc))],
        do: [gen(var(:user), :may_read, var(:doc))]
      ),

      # Effective access. Suspended users and explicit denials lose all access,
      # and archived documents become read-only.
      rule(:can_read,
        forall: [
          has(var(:user), :may_read, var(:doc)),
          neg(var(:user), :suspended, true),
          neg(var(:user), :denied, var(:doc))
        ],
        do: [gen(var(:user), :can_read, var(:doc))]
      ),
      rule(:can_write,
        forall: [
          has(var(:user), :may_write, var(:doc)),
          neg(var(:user), :suspended, true),
          neg(var(:user), :denied, var(:doc)),
          neg(var(:doc), :archived, true)
        ],
        do: [gen(var(:user), :can_write, var(:doc))]
      ),

      # Reports for the administrators.
      rule(:reader_count,
        forall: [
          has(var(:user), :can_read, var(:doc)),
          aggregate(&Enum.count/1, :readers, over: :user, partition: :doc)
        ],
        do: [gen(var(:doc), :reader_count, var(:readers))]
      ),
      rule(:widely_shared,
        forall: [
          has(var(:doc), :reader_count, var(:readers)),
          gte(var(:readers), 3)
        ],
        do: [gen(var(:doc), :widely_shared, true)]
      ),
      # A document nobody can read any more.
      rule(:orphaned,
        forall: [
          has(var(:doc), :is, :document),
          neg(:_, :can_read, var(:doc))
        ],
        do: [gen(var(:doc), :orphaned, true)]
      ),
      # A document nobody but its owner can read.
      rule(:private,
        forall: [
          has(var(:doc), :owner, var(:owner)),
          ncc([
            has(var(:reader), :can_read, var(:doc)),
            diff(var(:reader), var(:owner))
          ])
        ],
        do: [gen(var(:doc), :private, true)]
      ),
      # Someone other than the owner can edit the document.
      rule(:shared_editing,
        forall: [
          has(var(:doc), :owner, var(:owner)),
          has(var(:editor), :can_write, var(:doc)),
          diff(var(:editor), var(:owner))
        ],
        do: [gen(var(:doc), :edited_by_others, true)]
      ),
      # Group grants that reach nobody, because no active user is a member.
      rule(:dead_grant,
        forall: [
          has(var(:group), :grant_read, var(:target)),
          in_list(var(:group), @groups),
          ncc([
            has(var(:user), :in_group, var(:group)),
            has(var(:user), :is, :user),
            neg(var(:user), :suspended, true)
          ])
        ],
        do: [gen(var(:group), :unused_grant, var(:target))]
      )
    ]
  end

  @impl Wongi.Scenario
  def fact do
    principals = @users ++ @groups
    targets = @docs ++ @folders

    StreamData.frequency([
      {3, triple(@users, :is, :user)},
      {3, triple(@docs, :is, :document)},
      {3, triple(@users, :member_of, @groups)},
      {2, triple(@groups, :part_of, @groups)},
      {3, triple(@docs ++ @folders, :in_folder, @folders)},
      {3, triple(principals, :grant_read, targets)},
      {2, triple(principals, :grant_write, targets)},
      {2, triple(@docs, :owner, @users)},
      {1, triple(@users, :denied, @docs)},
      {1, triple(@users, :suspended, true)},
      {1, triple(@docs, :archived, true)}
    ])
  end
end
