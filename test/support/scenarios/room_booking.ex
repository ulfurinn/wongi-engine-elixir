defmodule Wongi.Scenarios.RoomBooking do
  @moduledoc false
  # Meeting room bookings for one day in an office.
  #
  # A booking is for a room, from one hour to another, with an organiser and
  # attendees, and may need some equipment. The rules find clashes, overfull
  # rooms and missing equipment, suggest other rooms, and confirm bookings
  # with nothing wrong with them.
  #
  # Input facts:
  #
  #   {booking, :room, room}           {booking, :organiser, person}
  #   {booking, :from, hour}           {booking, :until, hour}
  #   {booking, :attendee, person}     {booking, :needs, equipment}
  #   {room, :capacity, n}             {room, :has, equipment}
  #   {room, :closed, true}
  #
  # A booking may well have two rooms or two start times; the rules then
  # consider every combination.
  @behaviour Wongi.Scenario

  use Wongi.Engine.DSL
  import Wongi.Scenario, only: [triple: 3]

  @bookings [:standup, :review, :interview, :offsite]
  @rooms [:atrium, :library, :cellar]
  @people [:judy, :mallory, :niaj, :olivia]
  @equipment [:projector, :whiteboard]

  @impl Wongi.Scenario
  def rules do
    [
      rule(:malformed,
        forall: [
          has(var(:booking), :from, var(:from)),
          has(var(:booking), :until, var(:until)),
          lte(var(:until), var(:from))
        ],
        do: [gen(var(:booking), :malformed, true)]
      ),
      # Two bookings overlap when each starts before the other ends.
      rule(:room_clash,
        forall: [
          has(var(:a), :room, var(:room)),
          has(var(:b), :room, var(:room)),
          diff(var(:a), var(:b)),
          has(var(:a), :from, var(:a_from)),
          has(var(:a), :until, var(:a_until)),
          has(var(:b), :from, var(:b_from)),
          has(var(:b), :until, var(:b_until)),
          less(var(:a_from), var(:b_until)),
          less(var(:b_from), var(:a_until))
        ],
        do: [gen(var(:a), :clashes_with, var(:b))]
      ),
      # The same overlap, for people rather than rooms.
      rule(:double_booked,
        forall: [
          has(var(:a), :attendee, var(:person)),
          has(var(:b), :attendee, var(:person)),
          diff(var(:a), var(:b)),
          has(var(:a), :from, var(:a_from)),
          has(var(:a), :until, var(:a_until)),
          has(var(:b), :from, var(:b_from)),
          has(var(:b), :until, var(:b_until)),
          less(var(:a_from), var(:b_until)),
          less(var(:b_from), var(:a_until))
        ],
        do: [gen(var(:person), :double_booked, var(:a))]
      ),
      # The organiser always attends.
      rule(:organiser_attends,
        forall: [has(var(:booking), :organiser, var(:person))],
        do: [gen(var(:booking), :attendee, var(:person))]
      ),
      rule(:headcount,
        forall: [
          has(var(:booking), :attendee, var(:person)),
          aggregate(&Enum.count/1, :headcount, over: :person, partition: :booking)
        ],
        do: [gen(var(:booking), :headcount, var(:headcount))]
      ),
      rule(:over_capacity,
        forall: [
          has(var(:booking), :headcount, var(:headcount)),
          has(var(:booking), :room, var(:room)),
          has(var(:room), :capacity, var(:capacity)),
          greater(var(:headcount), var(:capacity))
        ],
        do: [gen(var(:booking), :over_capacity, true)]
      ),
      rule(:missing_equipment,
        forall: [
          has(var(:booking), :needs, var(:equipment)),
          has(var(:booking), :room, var(:room)),
          neg(var(:room), :has, var(:equipment))
        ],
        do: [gen(var(:booking), :missing, var(:equipment))]
      ),
      rule(:needs_attention,
        forall: [
          has(var(:booking), :room, var(:room)),
          any([
            [has(var(:booking), :clashes_with, :_)],
            [has(var(:booking), :over_capacity, true)],
            [has(var(:booking), :malformed, true)],
            [has(var(:room), :closed, true)]
          ])
        ],
        do: [gen(var(:booking), :needs_attention, true)]
      ),
      # A booking is confirmed when its room has all it needs and nothing else
      # is wrong with it.
      rule(:confirmed,
        forall: [
          has(var(:booking), :room, var(:room)),
          has(var(:booking), :from, :_),
          ncc([
            has(var(:booking), :needs, var(:equipment)),
            neg(var(:room), :has, var(:equipment))
          ]),
          neg(var(:booking), :needs_attention, true)
        ],
        do: [gen(var(:booking), :confirmed, true)]
      ),
      # Suggest other open rooms that are big enough and have the equipment.
      rule(:alternative_room,
        forall: [
          has(var(:booking), :needs_attention, true),
          has(var(:booking), :headcount, var(:headcount)),
          has(var(:other), :capacity, var(:capacity)),
          gte(var(:capacity), var(:headcount)),
          neg(var(:other), :closed, true),
          ncc([
            has(var(:booking), :needs, var(:equipment)),
            neg(var(:other), :has, var(:equipment))
          ]),
          neg(var(:booking), :room, var(:other))
        ],
        do: [gen(var(:booking), :could_move_to, var(:other))]
      ),
      rule(:long_meeting,
        forall: [
          has(var(:booking), :from, var(:from)),
          has(var(:booking), :until, var(:until)),
          assign(:length, &(&1[:until] - &1[:from])),
          filter(var(:length), &(&1 >= 3))
        ],
        do: [gen(var(:booking), :long, true)]
      ),
      rule(:busiest,
        forall: [
          has(:_, :headcount, var(:headcount)),
          aggregate(&max/1, :busiest, over: :headcount)
        ],
        do: [gen(:office, :busiest_meeting, var(:busiest))]
      )
    ]
  end

  @impl Wongi.Scenario
  def fact do
    StreamData.frequency([
      {3, triple(@bookings, :room, @rooms)},
      {2, triple(@bookings, :organiser, @people)},
      {3, triple(@bookings, :from, [9, 10, 11])},
      {3, triple(@bookings, :until, [10, 11, 13])},
      {3, triple(@bookings, :attendee, @people)},
      {2, triple(@bookings, :needs, @equipment)},
      {2, triple(@rooms, :capacity, [2, 3, 10])},
      {2, triple(@rooms, :has, @equipment)},
      {1, triple(@rooms, :closed, true)}
    ])
  end
end
