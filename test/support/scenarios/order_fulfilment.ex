defmodule Wongi.Scenarios.OrderFulfilment do
  @moduledoc false
  # Stock, orders and shipping for a small web shop.
  #
  # Stock is held in lots, each of some product in some warehouse. Orders have
  # lines, each for some quantity of a product. The rules work out what is in
  # stock, which orders can ship, what needs reordering, and what discounts
  # apply.
  #
  # Input facts:
  #
  #   {lot, :product, product}         {lot, :units, n}
  #   {lot, :warehouse, warehouse}     {warehouse, :closed, true}
  #   {line, :order, order}            {line, :product, product}
  #   {line, :quantity, n}             {order, :status, :placed | :cancelled}
  #   {order, :customer, customer}     {customer, :tier, :gold}
  #   {customer, :employee, true}      {product, :price, n}
  #   {product, :reorder_level, n}     {product, :discontinued, true}
  @behaviour Wongi.Scenario

  use Wongi.Engine.DSL
  import Wongi.Scenario, only: [triple: 3]

  @lots [:lot1, :lot2, :lot3, :lot4]
  @warehouses [:north, :south]
  @products [:kettle, :teapot]
  @orders [:order1, :order2, :order3]
  @lines [:line1, :line2, :line3, :line4]
  @customers [:erin, :frank]

  @impl Wongi.Scenario
  def rules do
    [
      # Lots in a closed warehouse cannot be shipped from.
      rule(:usable_lot,
        forall: [
          has(var(:lot), :product, var(:product)),
          has(var(:lot), :warehouse, var(:warehouse)),
          neg(var(:warehouse), :closed, true),
          has(var(:lot), :units, var(:units))
        ],
        do: [gen(var(:lot), :usable_units, var(:units))]
      ),
      rule(:available,
        forall: [
          has(var(:lot), :product, var(:product)),
          has(var(:lot), :usable_units, var(:units)),
          aggregate(&sum/1, :available, over: :units, partition: :product)
        ],
        do: [gen(var(:product), :available, var(:available))]
      ),

      # Only placed orders count towards demand.
      rule(:open_line,
        forall: [
          has(var(:line), :order, var(:order)),
          has(var(:order), :status, :placed),
          neg(var(:order), :status, :cancelled),
          has(var(:line), :product, var(:product)),
          has(var(:line), :quantity, var(:quantity))
        ],
        do: [gen(var(:line), :open_quantity, var(:quantity))]
      ),
      rule(:demand,
        forall: [
          has(var(:line), :product, var(:product)),
          has(var(:line), :open_quantity, var(:quantity)),
          aggregate(&sum/1, :demand, over: :quantity, partition: :product)
        ],
        do: [gen(var(:product), :demand, var(:demand))]
      ),

      # A product is short when there is more demand than stock, including when
      # there is no stock at all. Both rules can derive the same fact.
      rule(:short_of_stock,
        forall: [
          has(var(:product), :demand, var(:demand)),
          has(var(:product), :available, var(:available)),
          greater(var(:demand), var(:available))
        ],
        do: [gen(var(:product), :short, true)]
      ),
      rule(:out_of_stock,
        forall: [
          has(var(:product), :demand, var(:demand)),
          neg(var(:product), :available, :_)
        ],
        do: [gen(var(:product), :short, true)]
      ),

      # An order ships when none of its lines are for a product that is short.
      rule(:ready_to_ship,
        forall: [
          has(var(:order), :status, :placed),
          neg(var(:order), :status, :cancelled),
          has(:_, :order, var(:order)),
          ncc([
            has(var(:line), :order, var(:order)),
            has(var(:line), :product, var(:product)),
            has(var(:product), :short, true)
          ])
        ],
        do: [gen(var(:order), :ready_to_ship, true)]
      ),
      rule(:held_back,
        forall: [
          has(var(:line), :order, var(:order)),
          has(var(:line), :open_quantity, :_),
          has(var(:line), :product, var(:product)),
          has(var(:product), :short, true)
        ],
        do: [gen(var(:order), :waiting_for, var(:product))]
      ),

      # Reorder when stock falls to the reorder level, unless the product is
      # being discontinued.
      rule(:reorder,
        forall: [
          has(var(:product), :reorder_level, var(:level)),
          has(var(:product), :available, var(:available)),
          lte(var(:available), var(:level)),
          neg(var(:product), :discontinued, true)
        ],
        do: [gen(var(:product), :reorder, true)]
      ),

      # Prices.
      rule(:line_value,
        forall: [
          has(var(:line), :open_quantity, var(:quantity)),
          has(var(:line), :product, var(:product)),
          has(var(:product), :price, var(:price)),
          assign(:value, &(&1[:quantity] * &1[:price]))
        ],
        do: [gen(var(:line), :value, var(:value))]
      ),
      rule(:order_total,
        forall: [
          has(var(:line), :order, var(:order)),
          has(var(:line), :value, var(:value)),
          aggregate(&sum/1, :total, over: :value, partition: :order)
        ],
        do: [gen(var(:order), :total, var(:total))]
      ),
      rule(:free_shipping,
        forall: [
          has(var(:order), :total, var(:total)),
          gte(var(:total), 100)
        ],
        do: [gen(var(:order), :free_shipping, true)]
      ),

      # Gold customers, staff and repeat customers get a discount.
      rule(:placed_orders,
        forall: [
          has(var(:order), :customer, var(:customer)),
          has(var(:order), :status, :placed),
          aggregate(&Enum.count/1, :count, over: :order, partition: :customer)
        ],
        do: [gen(var(:customer), :placed_orders, var(:count))]
      ),
      rule(:discount,
        forall: [
          has(var(:order), :customer, var(:customer)),
          has(var(:order), :status, :placed),
          any([
            [has(var(:customer), :tier, :gold)],
            [has(var(:customer), :employee, true)],
            [has(var(:customer), :placed_orders, var(:count)), gte(var(:count), 2)]
          ])
        ],
        do: [gen(var(:order), :discount, true)]
      ),

      # The same customer ordering the same product in two orders at once is
      # probably a mistake.
      rule(:duplicate_order,
        forall: [
          has(var(:line1), :product, var(:product)),
          has(var(:line1), :order, var(:order1)),
          has(var(:order1), :customer, var(:customer)),
          has(var(:line2), :product, var(:product)),
          has(var(:line2), :order, var(:order2)),
          has(var(:order2), :customer, var(:customer)),
          less(var(:order1), var(:order2))
        ],
        do: [gen(var(:customer), :possible_duplicate, var(:product))]
      ),

      # Stock across the whole shop.
      rule(:total_stock,
        forall: [
          has(:_, :usable_units, var(:units)),
          aggregate(&sum/1, :total, over: :units)
        ],
        do: [gen(:shop, :total_units, var(:total))]
      )
    ]
  end

  @impl Wongi.Scenario
  def fact do
    StreamData.frequency([
      {4, triple(@lots, :product, @products)},
      {4, triple(@lots, :units, [0, 1, 2, 5])},
      {4, triple(@lots, :warehouse, @warehouses)},
      {1, triple(@warehouses, :closed, true)},
      {3, triple(@lines, :order, @orders)},
      {3, triple(@lines, :product, @products)},
      {3, triple(@lines, :quantity, [1, 3, 5, 10])},
      {4, triple(@orders, :status, [:placed, :placed, :placed, :cancelled])},
      {2, triple(@orders, :customer, @customers)},
      {1, triple(@customers, :tier, :gold)},
      {1, triple(@customers, :employee, true)},
      {3, triple(@products, :price, [5, 20, 50])},
      {2, triple(@products, :reorder_level, [2, 5])},
      {1, triple(@products, :discontinued, true)}
    ])
  end
end
