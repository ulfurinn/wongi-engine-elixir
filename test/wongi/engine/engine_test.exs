defmodule Wongi.Engine.EngineTest do
  use Wongi.TestCase

  setup do
    %{rete: new()}
  end

  describe "assert/2" do
    test "adds the WME to storage", %{rete: rete} do
      wme = WME.new(:a, :b, :c)

      rete =
        rete
        |> assert(:a, :b, :c)

      assert %{wmes: %{map: %{^wme => _}}} = rete
    end
  end

  describe "assert/4" do
    test "adds the WME to storage", %{rete: rete} do
      rete =
        rete
        |> assert(:a, :b, :c)

      wme = WME.new(:a, :b, :c)
      assert %{wmes: %{map: %{^wme => _}}} = rete
    end
  end

  describe "retract/4" do
    test "removes the WME from storage", %{rete: rete} do
      rete =
        rete
        |> assert(:a, :b, :c)
        |> retract(:a, :b, :c)

      assert %{wmes: %{map: %{}}} = rete
    end
  end

  describe "select/4" do
    test "retrieves after asserting", %{rete: rete} do
      rete =
        rete
        |> assert(:a, :b, :c)

      assert [WME.new(:a, :b, :c)] == select(rete, :a, :b, :c) |> Enum.to_list()
    end

    test "does not retrieve after retracting", %{rete: rete} do
      rete =
        rete
        |> assert(:a, :b, :c)
        |> retract(:a, :b, :c)

      assert [] == select(rete, :a, :b, :c) |> Enum.to_list()
    end

    test "retrieves by template after asserting", %{rete: rete} do
      rete =
        rete
        |> assert(:a, :b, :c)
        |> assert(:a, :b, :d)

      assert [WME.new(:a, :b, :c), WME.new(:a, :b, :d)] ==
               select(rete, :a, :_, :_) |> Enum.to_list()

      assert [WME.new(:a, :b, :c), WME.new(:a, :b, :d)] ==
               select(rete, :_, :b, :_) |> Enum.to_list()

      assert [WME.new(:a, :b, :c)] == select(rete, :_, :_, :c) |> Enum.to_list()

      assert [WME.new(:a, :b, :c), WME.new(:a, :b, :d)] ==
               select(rete, :a, :b, :_) |> Enum.to_list()

      assert [WME.new(:a, :b, :c)] == select(rete, :a, :_, :c) |> Enum.to_list()
      assert [WME.new(:a, :b, :c)] == select(rete, :_, :b, :c) |> Enum.to_list()
    end

    test "does not retrieve by template after retracting", %{rete: rete} do
      rete =
        rete
        |> assert(:a, :b, :c)
        |> assert(:a, :b, :d)
        |> retract(:a, :b, :c)
        |> retract(:a, :b, :d)

      assert [] == select(rete, :a, :_, :_) |> Enum.to_list()
      assert [] == select(rete, :_, :b, :_) |> Enum.to_list()
      assert [] == select(rete, :_, :_, :c) |> Enum.to_list()
      assert [] == select(rete, :a, :b, :_) |> Enum.to_list()
      assert [] == select(rete, :a, :_, :c) |> Enum.to_list()
      assert [] == select(rete, :_, :b, :c) |> Enum.to_list()
    end
  end
end
