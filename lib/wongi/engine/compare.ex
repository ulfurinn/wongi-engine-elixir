defmodule Wongi.Engine.Compare do
  @moduledoc """
  Compares terms for filters.

  Structs are compared through `Wongi.Engine.Comparable`. Lists, tuples, and
  maps recurse through `compare/2`, and other terms use term ordering.
  """

  alias Wongi.Engine.Comparable

  @type ordering :: :lt | :eq | :gt

  @doc "Compares two terms."
  @spec compare(term, term) :: ordering
  def compare(%mod{} = left, %mod{} = right) do
    case ask(left, right) do
      :unknown -> term_order(left, right)
      ordering -> ordering
    end
  end

  def compare(left, right) when is_struct(left) or is_struct(right) do
    left_answer = ask(left, right)
    right_answer = right |> ask(left) |> invert()

    case {left_answer, right_answer} do
      {:unknown, :unknown} -> term_order(left, right)
      {answer, answer} -> answer
      {answer, :unknown} -> answer
      {:unknown, answer} -> answer
      _ -> conflict!(left, right, left_answer, right_answer)
    end
  end

  def compare(left, right) when is_list(left) and is_list(right) do
    case compare_elements(left, right) do
      :eq -> term_order(length(left), length(right))
      ordering -> ordering
    end
  end

  def compare(left, right) when is_tuple(left) and is_tuple(right) do
    case term_order(tuple_size(left), tuple_size(right)) do
      :eq -> compare(Tuple.to_list(left), Tuple.to_list(right))
      ordering -> ordering
    end
  end

  def compare(left, right) when is_map(left) and is_map(right) do
    with :eq <- term_order(map_size(left), map_size(right)),
         :eq <- compare(Map.keys(left), Map.keys(right)) do
      compare(Map.values(left), Map.values(right))
    end
  end

  def compare(left, right), do: term_order(left, right)

  defp compare_elements(left, right) do
    left
    |> Stream.zip(right)
    |> Enum.reduce_while(:eq, fn {l, r}, :eq ->
      case compare(l, r) do
        :eq -> {:cont, :eq}
        ordering -> {:halt, ordering}
      end
    end)
  end

  defp ask(%mod{} = value, other) do
    case Comparable.compare(value, other) do
      result when result in [:lt, :eq, :gt, :unknown] ->
        result

      result ->
        raise ArgumentError,
              "expected Wongi.Engine.Comparable implementation for #{inspect(mod)} " <>
                "to return :lt, :eq, :gt, or :unknown, got: #{inspect(result)}"
    end
  end

  defp ask(_, _), do: :unknown

  defp invert(:lt), do: :gt
  defp invert(:gt), do: :lt
  defp invert(other), do: other

  defp term_order(left, right) when left == right, do: :eq
  defp term_order(left, right) when left > right, do: :gt
  defp term_order(_, _), do: :lt

  defp conflict!(%left_mod{}, %right_mod{}, left_answer, right_answer) do
    raise ArgumentError,
          "conflicting Wongi.Engine.Comparable implementations: #{inspect(left_mod)} " <>
            "compares #{inspect(left_answer)} against #{inspect(right_mod)}, but " <>
            "#{inspect(right_mod)} implies #{inspect(right_answer)}"
  end
end
