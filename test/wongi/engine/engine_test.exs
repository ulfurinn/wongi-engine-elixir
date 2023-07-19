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

      assert %{overlay: %{wmes: %{map: %{^wme => _}}}} = rete
    end
  end

  describe "assert/4" do
    test "adds the WME to storage", %{rete: rete} do
      rete =
        rete
        |> assert(:a, :b, :c)

      wme = WME.new(:a, :b, :c)
      assert %{overlay: %{wmes: %{map: %{^wme => _}}}} = rete
    end
  end

  describe "retract/2" do
    test "removes the WME from storage", %{rete: rete} do
      rete =
        rete
        |> assert(:a, :b, :c)
        |> retract(:a, :b, :c)

      assert %{overlay: %{wmes: %{map: %{}}}} = rete
    end
  end

  describe "find/2" do
    test "retrieves after asserting", %{rete: rete} do
      rete =
        rete
        |> assert(:a, :b, :c)

      assert [WME.new(:a, :b, :c)] == find(rete, :a, :b, :c) |> Enum.to_list()
    end

    test "does not retrieve after retracting", %{rete: rete} do
      rete =
        rete
        |> assert(:a, :b, :c)
        |> retract(:a, :b, :c)

      assert [] == find(rete, :a, :b, :c) |> Enum.to_list()
    end

    test "retrieves by template after asserting", %{rete: rete} do
      rete =
        rete
        |> assert(:a, :b, :c)
        |> assert(:a, :b, :d)

      assert [WME.new(:a, :b, :c), WME.new(:a, :b, :d)] ==
               find(rete, :a, :_, :_) |> Enum.to_list()

      assert [WME.new(:a, :b, :c), WME.new(:a, :b, :d)] ==
               find(rete, :_, :b, :_) |> Enum.to_list()

      assert [WME.new(:a, :b, :c)] == find(rete, :_, :_, :c) |> Enum.to_list()

      assert [WME.new(:a, :b, :c), WME.new(:a, :b, :d)] ==
               find(rete, :a, :b, :_) |> Enum.to_list()

      assert [WME.new(:a, :b, :c)] == find(rete, :a, :_, :c) |> Enum.to_list()
      assert [WME.new(:a, :b, :c)] == find(rete, :_, :b, :c) |> Enum.to_list()
    end

    test "does not retrieve by template after retracting", %{rete: rete} do
      rete =
        rete
        |> assert(:a, :b, :c)
        |> assert(:a, :b, :d)
        |> retract(:a, :b, :c)
        |> retract(:a, :b, :d)

      assert [] == find(rete, :a, :_, :_) |> Enum.to_list()
      assert [] == find(rete, :_, :b, :_) |> Enum.to_list()
      assert [] == find(rete, :_, :_, :c) |> Enum.to_list()
      assert [] == find(rete, :a, :b, :_) |> Enum.to_list()
      assert [] == find(rete, :a, :_, :c) |> Enum.to_list()
      assert [] == find(rete, :_, :b, :c) |> Enum.to_list()
    end
  end
end
