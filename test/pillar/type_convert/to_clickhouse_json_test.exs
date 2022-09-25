defmodule Pillar.TypeConvert.ToClickhouseJsonTest do
  alias Pillar.TypeConvert.ToClickhouseJson
  use ExUnit.Case

  describe "#convert/1" do
    test "Atom" do
      assert ToClickhouseJson.convert(:error) == "error"
    end

    test "Float" do
      assert ToClickhouseJson.convert(2.35) == "2.35"
    end

    test "Date" do
      assert ToClickhouseJson.convert(~D[1970-01-01]) == "1970-01-01"
    end

    test "String" do
      assert ToClickhouseJson.convert("Hello") == "Hello"

      assert ToClickhouseJson.convert("Hello, here is single qoute '") ==
               "Hello, here is single qoute '"

      assert ToClickhouseJson.convert("Hello, here are two single qoutes ''") ==
               "Hello, here are two single qoutes ''"

      assert ToClickhouseJson.convert("Hello, here are two double qoutes \"\"") ==
               "Hello, here are two double qoutes \"\""
    end

    test "Map" do
      assert ToClickhouseJson.convert(%{key: "value"}) == "{\"key\":\"value\"}"
    end

    test "Bool" do
      assert ToClickhouseJson.convert(true) == 1
      assert ToClickhouseJson.convert(false) == 0
    end

    test "DateTime" do
      assert ToClickhouseJson.convert(~U[2020-03-26 22:26:14.286832Z]) == "2020-03-26T22:26:14"
    end

    test "List" do
      assert ToClickhouseJson.convert([
               1,
               2,
               1,
               0,
               ~D[1970-01-01],
               %{"key" => "value"},
               ~U[2020-03-26 22:26:14.286832Z],
               "Le'Blank"
             ]) == [
               "1",
               "2",
               "1",
               "0",
               "1970-01-01",
               "{\"key\":\"value\"}",
               "2020-03-26T22:26:14",
               "Le'Blank"
             ]

      # array with array
      assert ToClickhouseJson.convert([
               []
             ]) == [[]]
    end

    test "Keyword" do
      assert ToClickhouseJson.convert(foo: "bar", baz: "bak") == %{"baz" => "bak", "foo" => "bar"}
    end
  end
end
