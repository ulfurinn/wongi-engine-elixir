defmodule Wongi.EngineTest do
  use ExUnit.Case

  import Wongi.Engine, only: [new: 0, find: 2]

  alias Wongi.Engine
  alias Wongi.Engine.WME

  setup do
    %{rete: new()}
  end

  describe "assert/2" do
    test "adds the WME to storage", %{rete: rete} do
      wme = WME.new(:a, :b, :c)

      rete =
        rete
        |> Engine.assert(wme)

      assert %{overlay: %{wmes: %{map: %{^wme => _}}}} = rete
    end
  end

  describe "assert/4" do
    test "adds the WME to storage", %{rete: rete} do
      rete =
        rete
        |> Engine.assert(:a, :b, :c)

      wme = WME.new(:a, :b, :c)
      assert %{overlay: %{wmes: %{map: %{^wme => _}}}} = rete
    end
  end

  describe "retract/2" do
    test "removes the WME from storage", %{rete: rete} do
      wme = WME.new(:a, :b, :c)

      rete =
        rete
        |> Engine.assert(wme)
        |> Engine.retract(wme)

      assert %{overlay: %{wmes: %{map: %{}}}} = rete
    end
  end

  describe "find/2" do
    test "retrieves after asserting", %{rete: rete} do
      rete =
        rete
        |> Engine.assert([:a, :b, :c])

      assert [WME.new(:a, :b, :c)] == find(rete, [:a, :b, :c])
    end

    test "does not retrieve after retracting", %{rete: rete} do
      rete =
        rete
        |> Engine.assert([:a, :b, :c])
        |> Engine.retract([:a, :b, :c])

      assert [] == find(rete, [:a, :b, :c])
    end

    test "retrieves by template after asserting", %{rete: rete} do
      rete =
        rete
        |> Engine.assert([:a, :b, :c])
        |> Engine.assert([:a, :b, :d])

      assert [WME.new(:a, :b, :c), WME.new(:a, :b, :d)] == find(rete, [:a, :_, :_])
      assert [WME.new(:a, :b, :c), WME.new(:a, :b, :d)] == find(rete, [:_, :b, :_])
      assert [WME.new(:a, :b, :c)] == find(rete, [:_, :_, :c])
      assert [WME.new(:a, :b, :c), WME.new(:a, :b, :d)] == find(rete, [:a, :b, :_])
      assert [WME.new(:a, :b, :c)] == find(rete, [:a, :_, :c])
      assert [WME.new(:a, :b, :c)] == find(rete, [:_, :b, :c])
    end

    test "does not retrieve by template after retracting", %{rete: rete} do
      rete =
        rete
        |> Engine.assert([:a, :b, :c])
        |> Engine.assert([:a, :b, :d])
        |> Engine.retract([:a, :b, :c])
        |> Engine.retract([:a, :b, :d])

      assert [] == find(rete, [:a, :_, :_])
      assert [] == find(rete, [:_, :b, :_])
      assert [] == find(rete, [:_, :_, :c])
      assert [] == find(rete, [:a, :b, :_])
      assert [] == find(rete, [:a, :_, :c])
      assert [] == find(rete, [:_, :b, :c])
    end
  end
end
