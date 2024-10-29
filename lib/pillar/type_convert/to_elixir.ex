defmodule Pillar.TypeConvert.ToElixir do
  @moduledoc false

  require Logger

  def convert("(" <> type_with_parenthese, value) do
    # For example (UInt64), this type returns when IF function returns NULL or Uint64
    # SELECT IF(1 == 2, NULL, 64)
    {type, ")"} = String.split_at(type_with_parenthese, -1)
    convert(type, value)
  end

  def convert("SimpleAggregateFunction" <> function_body, value) do
    [_, type] = Regex.run(~r/\(\w*, (.*)\)/, function_body)
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

  def convert("Bool", value) when is_boolean(value) do
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

  # DateTime64(3)
  # DateTime64(3, 'Europe/Moscow')
  def convert("DateTime64" <> rest, value) do
    params =
      rest
      |> strip_brackets()
      |> String.split(", ")

    if length(params) == 1 do
      convert("DateTime", value)
    else
      [_precision, time_zone] = params
      convert_datetime_with_timezone(value, strip_quotes(time_zone))
    end
  end

  def convert("DateTime", value) do
    {:ok, datetime, _offset} = DateTime.from_iso8601(value <> "Z")
    datetime
  end

  # DateTime('Europe/Moscow')
  def convert("DateTime" <> time_zone, value) do
    time_zone =
      time_zone
      |> strip_brackets
      |> strip_quotes

    convert_datetime_with_timezone(value, time_zone)
  end

  def convert("Date", "0000-00-00") do
    nil
  end

  def convert("Date", value) do
    Date.from_iso8601!(value)
  end

  def convert("Date32", value) do
    Date.from_iso8601!(value)
  end

  def convert("IPv4", value) do
    value
  end

  def convert("IPv6", value) do
    value
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

  def convert("Decimal" <> _decimal_subtypes, value) when is_integer(value),
    do: Decimal.new(value)

  def convert("Decimal" <> _decimal_subtypes, value) when is_float(value),
    do: Decimal.from_float(value)

  def convert("Map" <> _key_values_types, pairs) do
    Keyword.new(pairs, fn {k, v} -> {String.to_atom(k), v} end)
  end

  def convert("Tuple" <> schema, values) do
    key_types =
      schema
      |> String.trim_leading("(")
      |> String.trim_trailing(")")
      |> String.split([", "])

    acc = %{res: [], type: nil}

    Enum.zip(key_types, values)
    |> Enum.reduce(acc, fn
      {key_type, {_key, value}}, acc ->
        [key, type] = String.split(key_type)
        elem = {key, convert(type, value)}
        res = [elem | acc.res]
        %{res: res, type: :map}

      {key_type, value}, acc ->
        res = [convert(key_type, value) | acc.res]
        %{res: res, type: :list}
    end)
    |> case do
      %{type: :list, res: res} -> Enum.reverse(res)
      %{type: :map, res: res} -> Map.new(res)
    end
  end

  defp convert_datetime_with_timezone(value, time_zone) do
    [date, time] = String.split(value, " ")

    case Code.ensure_loaded?(DateTime) && function_exported?(DateTime, :new, 3) &&
           DateTime.new(Date.from_iso8601!(date), Time.from_iso8601!(time), time_zone) do
      false ->
        {:error, "feature needs elixir v1.11 minimum"}

      {:ok, datetime} ->
        datetime

      {:error, :utc_only_time_zone_database} ->
        Logger.warning(
          "Add timezone database to your project if you want to use Timezones (tzdata or tz)."
        )

        {:error, :utc_only_time_zone_database}
    end
  end

  defp strip_brackets(value) do
    value
    |> String.replace_leading("(", "")
    |> String.replace_trailing(")", "")
  end

  defp strip_quotes(value) do
    value
    |> String.replace_leading("'", "")
    |> String.replace_trailing("'", "")
  end
end
