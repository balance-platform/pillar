defmodule Pillar.TypeConvert.ToElixir do
  @moduledoc false

  def convert("(" <> type_with_parenthese, value) do
    # For example (UInt64), this type returns when IF function returns NULL or Uint64
    # SELECT IF(1 == 2, NULL, 64)
    {type, ")"} = String.split_at(type_with_parenthese, -1)
    convert(type, value)
  end

  def convert("String", value) do
    value
  end

  def convert("LowCardinality" <> type, value) do
    convert(type, value)
  end

  def convert("UUID", value) do
    value
  end

  def convert("FixedString" <> _size, value) when is_binary(value) do
    String.Chars.to_string(value)
  end

  def convert("FixedString" <> _size, value) do
    value
  end

  def convert("Nullable" <> type, value) do
    case is_nil(value) do
      true -> nil
      false -> convert(type, value)
    end
  end

  def convert("Array" <> array_subtype, list) do
    type = String.replace(array_subtype, ["(", ")"], "")
    Enum.map(list, fn value -> convert(type, value) end)
  end

  def convert("Enum8" <> _enum_values, value) do
    value
  end

  def convert("DateTime", "0000-00-00 00:00:00") do
    nil
  end

  def convert("DateTime64(3)", value), do: convert("DateTime", value)

  def convert("DateTime", value) do
    {:ok, datetime, _offset} = DateTime.from_iso8601(value <> "Z")
    datetime
  end

  def convert("Date", "0000-00-00") do
    nil
  end

  def convert("Date", value) do
    Date.from_iso8601!(value)
  end

  def convert(clickhouse_type, value)
      when clickhouse_type in [
             "Int64",
             "UInt64"
           ] and is_binary(value) do
    String.to_integer(value)
  end

  def convert(clickhouse_type, value)
      when clickhouse_type in [
             "Int8",
             "Int16",
             "Int32",
             "UInt8",
             "UInt16",
             "UInt32"
           ] and is_integer(value) do
    value
  end

  def convert(clickhouse_type, value)
      when clickhouse_type in [
             "Float32",
             "Float64"
           ] and is_number(value) do
    value
  end
end
