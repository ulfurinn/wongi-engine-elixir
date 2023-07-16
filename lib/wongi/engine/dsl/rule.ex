defmodule Wongi.Engine.DSL.Rule do
  @moduledoc false
  defstruct [:ref, :name, :forall, :do]

  def new(name, forall, do_) do
    %__MODULE__{
      ref: make_ref(),
      name: name,
      forall: forall,
      do: do_
    }
  end
end
