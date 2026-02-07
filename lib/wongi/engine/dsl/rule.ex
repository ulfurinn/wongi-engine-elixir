defmodule Wongi.Engine.DSL.Rule do
  @moduledoc false

  @typedoc """
  Mode for RuleBuilder execution:
  - `:full` - normal mode, allows both matchers and actions
  - `:matcher_only` - only matchers allowed, actions raise an error
  """
  @type mode() :: :full | :matcher_only

  @type t() :: %__MODULE__{
          ref: reference() | nil,
          name: atom() | nil,
          forall: list(),
          actions: list(),
          mode: mode(),
          bound_vars: MapSet.t(atom())
        }

  defstruct ref: nil,
            name: nil,
            forall: [],
            actions: [],
            mode: :full,
            bound_vars: MapSet.new()

  @doc false
  def new(name, forall, actions) do
    %__MODULE__{
      ref: make_ref(),
      name: name,
      forall: forall,
      actions: actions,
      mode: :full,
      bound_vars: MapSet.new()
    }
  end
end
