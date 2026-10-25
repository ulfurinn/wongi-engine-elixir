defmodule Wongi.Scenarios.OrderFulfilmentTest do
  use Wongi.TestCase

  import Wongi.Scenario, only: [objects: 3, subjects: 3]

  alias Wongi.Scenario
  alias Wongi.Scenarios.OrderFulfilment

  setup do
    rete =
      OrderFulfilment
      |> Scenario.engine()
      |> Scenario.assert_all([
        {:lot1, :product, :kettle},
        {:lot1, :warehouse, :north},
        {:lot1, :units, 5},
        {:lot2, :product, :kettle},
        {:lot2, :warehouse, :south},
        {:lot2, :units, 2}
      ])

    %{rete: rete}
  end

  test "stock adds up across lots in open warehouses", %{rete: rete} do
    assert [7] = objects(rete, :kettle, :available)
    assert [7] = objects(rete, :shop, :total_units)

    rete = assert(rete, :south, :closed, true)
    assert [5] = objects(rete, :kettle, :available)
    assert [5] = objects(rete, :shop, :total_units)

    rete =
      assert(rete, :lot3, :product, :teapot)
      |> assert(:lot3, :warehouse, :south)
      |> assert(:lot3, :units, 1)

    assert [] = objects(rete, :teapot, :available)

    rete = retract(rete, :south, :closed, true)
    assert [1] = objects(rete, :teapot, :available)
    assert [8] = objects(rete, :shop, :total_units)
  end

  test "an order ships when there is stock for all of its lines", %{rete: rete} do
    rete =
      Scenario.assert_all(rete, [
        {:order1, :status, :placed},
        {:line1, :order, :order1},
        {:line1, :product, :kettle},
        {:line1, :quantity, 3}
      ])

    assert [3] = objects(rete, :kettle, :demand)
    assert [true] = objects(rete, :order1, :ready_to_ship)

    # a second order takes demand past what is available
    rete =
      Scenario.assert_all(rete, [
        {:order2, :status, :placed},
        {:line2, :order, :order2},
        {:line2, :product, :kettle},
        {:line2, :quantity, 5}
      ])

    assert [8] = objects(rete, :kettle, :demand)
    assert [true] = objects(rete, :kettle, :short)
    assert [] = subjects(rete, :ready_to_ship, true)
    assert [:order1, :order2] = subjects(rete, :waiting_for, :kettle)

    # cancelling it frees the stock again
    rete = assert(rete, :order2, :status, :cancelled)
    assert [3] = objects(rete, :kettle, :demand)
    assert [] = objects(rete, :kettle, :short)
    assert [:order1] = subjects(rete, :ready_to_ship, true)
    assert [] = subjects(rete, :waiting_for, :kettle)
  end

  test "a product with no stock at all is short", %{rete: rete} do
    rete =
      Scenario.assert_all(rete, [
        {:order1, :status, :placed},
        {:line1, :order, :order1},
        {:line1, :product, :kettle},
        {:line1, :quantity, 1},
        {:line2, :order, :order1},
        {:line2, :product, :teapot},
        {:line2, :quantity, 1}
      ])

    assert [true] = objects(rete, :teapot, :short)
    assert [:teapot] = objects(rete, :order1, :waiting_for)
    assert [] = objects(rete, :order1, :ready_to_ship)

    rete =
      rete
      |> assert(:lot3, :product, :teapot)
      |> assert(:lot3, :warehouse, :north)
      |> assert(:lot3, :units, 1)

    assert [] = objects(rete, :teapot, :short)
    assert [true] = objects(rete, :order1, :ready_to_ship)
  end

  test "prices, totals and free shipping", %{rete: rete} do
    rete =
      Scenario.assert_all(rete, [
        {:kettle, :price, 20},
        {:teapot, :price, 5},
        {:order1, :status, :placed},
        {:line1, :order, :order1},
        {:line1, :product, :kettle},
        {:line1, :quantity, 3},
        {:line2, :order, :order1},
        {:line2, :product, :teapot},
        {:line2, :quantity, 10}
      ])

    assert [60] = objects(rete, :line1, :value)
    assert [50] = objects(rete, :line2, :value)
    assert [110] = objects(rete, :order1, :total)
    assert [true] = objects(rete, :order1, :free_shipping)

    rete = retract(rete, :line2, :quantity, 10)
    assert [60] = objects(rete, :order1, :total)
    assert [] = objects(rete, :order1, :free_shipping)
  end

  test "discounts for gold customers, staff and repeat customers", %{rete: rete} do
    rete =
      Scenario.assert_all(rete, [
        {:order1, :status, :placed},
        {:order1, :customer, :erin},
        {:order2, :status, :placed},
        {:order2, :customer, :frank}
      ])

    assert [] = subjects(rete, :discount, true)

    rete = assert(rete, :erin, :employee, true)
    assert [:order1] = subjects(rete, :discount, true)

    rete = rete |> assert(:order3, :status, :placed) |> assert(:order3, :customer, :frank)
    assert [2] = objects(rete, :frank, :placed_orders)
    assert [:order1, :order2, :order3] = subjects(rete, :discount, true)

    rete = assert(rete, :frank, :tier, :gold) |> retract(:order3, :customer, :frank)
    assert [1] = objects(rete, :frank, :placed_orders)
    assert [:order1, :order2] = subjects(rete, :discount, true)
  end

  test "reorders and suspected duplicates", %{rete: rete} do
    rete = assert(rete, :kettle, :reorder_level, 5)
    assert [] = objects(rete, :kettle, :reorder)

    rete = assert(rete, :south, :closed, true)
    assert [true] = objects(rete, :kettle, :reorder)

    rete = assert(rete, :kettle, :discontinued, true)
    assert [] = objects(rete, :kettle, :reorder)

    rete =
      Scenario.assert_all(rete, [
        {:order1, :customer, :frank},
        {:line1, :order, :order1},
        {:line1, :product, :kettle},
        {:order2, :customer, :frank},
        {:line2, :order, :order2},
        {:line2, :product, :kettle}
      ])

    assert [:kettle] = objects(rete, :frank, :possible_duplicate)
  end
end
