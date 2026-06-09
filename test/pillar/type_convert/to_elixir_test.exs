defmodule Pillar.TypeConvert.ToElixirTest do
  alias Pillar.TypeConvert.ToElixir
  use ExUnit.Case

  describe "#convert/2" do
    test "Float64" do
      assert ToElixir.convert("Float64", 42.5) == 42.5
    end

    test "Int64" do
      assert ToElixir.convert("Int64", "7") == 7
    end

    test "Nullable returns nil for a null value" do
      assert ToElixir.convert("Nullable(Float64)", nil) == nil
    end

    test "null in a non-Nullable numeric column decodes to nil" do
      # ClickHouse serialises NaN/Inf as JSON null under a bare Float64/Int64.
      assert ToElixir.convert("Float64", nil) == nil
      assert ToElixir.convert("Int64", nil) == nil
    end

    test "a null array element decodes to nil element-wise" do
      assert ToElixir.convert("Array(Float64)", [1.0, nil, 2.0]) == [1.0, nil, 2.0]
    end

    test "a null array column decodes to nil" do
      assert ToElixir.convert("Array(Float64)", nil) == nil
    end
  end
end
