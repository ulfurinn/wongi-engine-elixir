defmodule Wongi.Test.Comparables.Money do
  @moduledoc false
  defstruct [:cents]
end

defmodule Wongi.Test.Comparables.Declining do
  @moduledoc false
  defstruct [:d]
end

defmodule Wongi.Test.Comparables.BadImpl do
  @moduledoc false
  defstruct []
end

defmodule Wongi.Test.Comparables.ConflictA do
  @moduledoc false
  defstruct []
end

defmodule Wongi.Test.Comparables.ConflictB do
  @moduledoc false
  defstruct []
end

defmodule Wongi.Test.Comparables.Reversed do
  @moduledoc false
  defstruct [:rank]

  def compare(%__MODULE__{rank: a}, %__MODULE__{rank: b}) do
    cond do
      a > b -> :lt
      a < b -> :gt
      true -> :eq
    end
  end
end

defmodule Wongi.Test.Comparables.BadCompare do
  @moduledoc false
  defstruct [:value]

  def compare(%__MODULE__{value: value}, %__MODULE__{}), do: value
end

defmodule Wongi.Test.Comparables.RaisingCompare do
  @moduledoc false
  defstruct []

  def compare(%__MODULE__{}, %__MODULE__{}), do: raise("broken compare")
end

defmodule Wongi.Test.Comparables.Plain do
  @moduledoc false
  defstruct [:a]
end

defimpl Wongi.Engine.Comparable, for: Wongi.Test.Comparables.Money do
  alias Wongi.Engine.Compare
  alias Wongi.Test.Comparables.Money

  def compare(%Money{cents: a}, %Money{cents: b}), do: Compare.compare(a, b)
  def compare(%Money{cents: a}, b) when is_integer(b), do: Compare.compare(a, b)
  def compare(%Money{}, _), do: :unknown
end

defimpl Wongi.Engine.Comparable, for: Wongi.Test.Comparables.Declining do
  def compare(_, _), do: :unknown
end

defimpl Wongi.Engine.Comparable, for: Wongi.Test.Comparables.BadImpl do
  def compare(_, _), do: :nope
end

defimpl Wongi.Engine.Comparable, for: Wongi.Test.Comparables.ConflictA do
  alias Wongi.Test.Comparables.ConflictB

  def compare(_, %ConflictB{}), do: :gt
  def compare(_, _), do: :unknown
end

defimpl Wongi.Engine.Comparable, for: Wongi.Test.Comparables.ConflictB do
  alias Wongi.Test.Comparables.ConflictA

  def compare(_, %ConflictA{}), do: :gt
  def compare(_, _), do: :unknown
end

defimpl Wongi.Engine.Comparable, for: Integer do
  def compare(_, _), do: :gt
end
