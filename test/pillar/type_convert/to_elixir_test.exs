defmodule Pillar.TypeConvert.ToElixirTest do
  alias Pillar.TypeConvert.ToElixir
  use ExUnit.Case

  describe "#convert/1" do
    test "DateTime('Europe/Moscow')" do
      assert ToElixir.convert("DateTime('Europe/Moscow')", "2021-10-20 16:55:48") ==
               ~U[2021-10-20 16:55:48Z]
    end
  end
end
