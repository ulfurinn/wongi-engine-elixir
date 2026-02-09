defmodule Wongi.Engine.DSL.RuleBuilderState do
  @moduledoc """
  Internal state struct for RuleBuilder's state monad.

  Wraps a Rule struct along with builder-specific fields that are only
  needed during rule construction, not at runtime.
  """

  alias Wongi.Engine.DSL.Rule

  @type t :: %__MODULE__{
          rule: Rule.t(),
          mode: :full | :matcher_only,
          bound_vars: MapSet.t(atom())
        }

  defstruct rule: nil, mode: :full, bound_vars: MapSet.new()
end
