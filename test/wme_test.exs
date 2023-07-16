defmodule Wongi.Engine.WMETest do
  use ExUnit.Case

  import Wongi.Engine.WME

  describe "new/1" do
    test "creates a WME" do
      assert %Wongi.Engine.WME{subject: :a, predicate: :b, object: :c} = new([:a, :b, :c])
    end
  end

  describe "new/3" do
    test "creates a WME" do
      assert %Wongi.Engine.WME{subject: :a, predicate: :b, object: :c} = new(:a, :b, :c)
    end
  end

  describe "wild?/1" do
    test "underscore is wild" do
      assert wild?(:_)
    end

    test "values are not wild" do
      assert not wild?(:x)
    end
  end

  describe "fetch/2" do
    setup do
      %{wme: new(:a, :b, :c)}
    end

    test "subject", %{wme: wme} do
      assert :a = wme[:subject]
    end

    test "predicate", %{wme: wme} do
      assert :b = wme[:predicate]
    end

    test "object", %{wme: wme} do
      assert :c = wme[:object]
    end
  end

  test "index pattern" do
    assert {[:subject], [:a]} = index_pattern(new(:a, :_, :_))
    assert {[:predicate], [:b]} = index_pattern(new(:_, :b, :_))
    assert {[:object], [:c]} = index_pattern(new(:_, :_, :c))
    assert {[:subject, :predicate], [:a, :b]} = index_pattern(new(:a, :b, :_))
    assert {[:subject, :object], [:a, :c]} = index_pattern(new(:a, :_, :c))
    assert {[:predicate, :object], [:b, :c]} = index_pattern(new(:_, :b, :c))
  end
end
