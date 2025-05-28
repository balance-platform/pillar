defmodule Pillar.TypeConvert.ToClickhouseJson do
  require Decimal

  alias Pillar.Util

  def convert(param, db_version \\ nil, query_options \\ %{})

  @moduledoc false
  def convert(param, db_version, query_options) when is_list(param) do
    if !Enum.empty?(param) && Keyword.keyword?(param) do
      param
      |> Enum.map(fn
        {k, d} -> {to_string(k), convert(d, db_version, query_options)}
      end)
      |> Enum.into(%{})
    else
      Enum.map(param, fn d ->
        convert(d, db_version, query_options)
      end)
    end
  end

  def convert(param, db_version, query_options) when Decimal.is_decimal(param) do
    fix_numbers(param, db_version, query_options)
  end

  def convert(param, _, _) when is_integer(param) do
    Integer.to_string(param)
  end

  def convert(true, _, _), do: 1
  def convert(false, _, _), do: 0
  def convert(nil, _, _), do: nil

  def convert(param, _, _) when is_atom(param) do
    Atom.to_string(param)
  end

  def convert(param, _, _) when is_float(param) do
    Float.to_string(param)
  end

  def convert(%DateTime{} = datetime, _, _) do
    datetime
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601()
    |> String.replace("Z", "")
  end

  def convert(%Date{} = date, _, _) do
    date
    |> Date.to_iso8601()
  end

  def convert(param, db_version, query_options) when is_map(param) do
    json = Jason.encode!(param)
    convert(json, db_version, query_options)
  end

  def convert(param, _, _) when is_binary(param) do
    param
  end

  def convert({:json, param}, db_version, query_options) do
    if Util.needs_decimal_zero_for_integers_in_json?(db_version),
      do: fix_numbers(param, db_version, query_options),
      else: param
  end

  def convert(param, _, _) do
    param
  end

  defp fix_numbers(i, _, _) when is_integer(i), do: i * 1.0

  defp fix_numbers(%Decimal{} = param, db_version, query_options) do
    cond do
      Util.needs_decimal_zero_for_integers_in_json?(db_version) ->
        if Decimal.integer?(param),
          do: Decimal.to_integer(param) * 1.0,
          else: Decimal.to_string(param)

      Util.has_input_format_json_read_numbers_as_strings?(db_version) ->
        Decimal.to_string(param)

      Map.get(query_options, :decimal_as_float) == true ->
        Decimal.to_float(param)

      :else ->
        raise "Your clickhouse version #{db_version} does not support inserting decimals as strings. " <>
                "You can allow converting decimals to floats by passing the option `query_options: %{decimal_as_float: true}` to insert_to_table"
    end
  end

  defp fix_numbers(%_{} = struct, _, _), do: struct

  defp fix_numbers(%{} = map, db_version, query_options),
    do: Map.new(map, fn {k, v} -> {k, fix_numbers(v, db_version, query_options)} end)

  defp fix_numbers(list, db_version, query_options) when is_list(list),
    do: Enum.map(list, &fix_numbers(&1, db_version, query_options))

  defp fix_numbers(any, _, _), do: any
end
