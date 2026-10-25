defmodule Wongi.Scenarios.RoomBookingTest do
  use Wongi.TestCase

  import Wongi.Scenario, only: [objects: 3, subjects: 3]

  alias Wongi.Scenario
  alias Wongi.Scenarios.RoomBooking

  setup do
    rete =
      RoomBooking
      |> Scenario.engine()
      |> Scenario.assert_all([
        {:atrium, :capacity, 10},
        {:atrium, :has, :projector},
        {:atrium, :has, :whiteboard},
        {:library, :capacity, 2},
        {:library, :has, :whiteboard},
        {:cellar, :capacity, 3}
      ])

    %{rete: rete}
  end

  defp book(rete, booking, room, from, until, organiser) do
    Scenario.assert_all(rete, [
      {booking, :room, room},
      {booking, :from, from},
      {booking, :until, until},
      {booking, :organiser, organiser}
    ])
  end

  test "bookings clash when their times overlap", %{rete: rete} do
    rete =
      rete
      |> book(:standup, :atrium, 9, 10, :judy)
      |> book(:review, :atrium, 9, 11, :mallory)
      |> book(:interview, :atrium, 10, 11, :niaj)

    assert [:review] = objects(rete, :standup, :clashes_with)
    assert [:interview, :standup] = objects(rete, :review, :clashes_with)
    assert [:review] = objects(rete, :interview, :clashes_with)
    assert [] = subjects(rete, :confirmed, true)

    rete = rete |> retract(:review, :room, :atrium) |> assert(:review, :room, :library)
    assert [] = subjects(rete, :clashes_with, :review)
    assert [:interview, :review, :standup] = subjects(rete, :confirmed, true)
  end

  test "people can be double booked across rooms", %{rete: rete} do
    rete =
      rete
      |> book(:standup, :atrium, 9, 10, :judy)
      |> book(:review, :library, 9, 11, :mallory)
      |> assert(:review, :attendee, :judy)

    assert [:review, :standup] = objects(rete, :judy, :double_booked)
    assert [] = objects(rete, :mallory, :double_booked)
  end

  test "headcount includes the organiser and is checked against capacity", %{rete: rete} do
    rete =
      rete
      |> book(:review, :library, 9, 10, :judy)
      |> assert(:review, :attendee, :mallory)

    assert [2] = objects(rete, :review, :headcount)
    assert [] = objects(rete, :review, :over_capacity)
    assert [true] = objects(rete, :review, :confirmed)

    # an attendee who also organises is only counted once
    rete = assert(rete, :review, :attendee, :judy)
    assert [2] = objects(rete, :review, :headcount)

    rete = assert(rete, :review, :attendee, :niaj)
    assert [3] = objects(rete, :review, :headcount)
    assert [true] = objects(rete, :review, :over_capacity)
    assert [] = objects(rete, :review, :confirmed)
    assert [:atrium, :cellar] = objects(rete, :review, :could_move_to)
    assert [3] = objects(rete, :office, :busiest_meeting)

    rete = assert(rete, :cellar, :closed, true)
    assert [:atrium] = objects(rete, :review, :could_move_to)
  end

  test "the room must have the equipment the booking needs", %{rete: rete} do
    rete =
      rete
      |> book(:interview, :library, 10, 11, :olivia)
      |> assert(:interview, :needs, :projector)

    assert [:projector] = objects(rete, :interview, :missing)
    assert [] = objects(rete, :interview, :confirmed)

    rete = assert(rete, :library, :has, :projector)
    assert [] = objects(rete, :interview, :missing)
    assert [true] = objects(rete, :interview, :confirmed)
  end

  test "malformed and long bookings", %{rete: rete} do
    rete =
      rete
      |> book(:standup, :atrium, 11, 10, :judy)
      |> book(:offsite, :cellar, 9, 13, :mallory)

    assert [:standup] = subjects(rete, :malformed, true)
    assert [:offsite] = subjects(rete, :long, true)
    assert [:standup] = subjects(rete, :needs_attention, true)
  end
end
