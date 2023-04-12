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
    cond do
      Util.has_input_format_json_read_numbers_as_strings?(db_version) ->
        Decimal.to_string(param)

      Map.get(query_options, :decimal_as_float) == true ->
        Decimal.to_float(param)

      :else ->
        raise "Your clickhouse version #{db_version} does not support inserting decimals as strings. You can allow converting decimals to floats by passing the option `query_options: %{decimal_as_float: true}` to insert_to_table"
    end
  end

  def convert(param, _, _) when is_integer(param) do
    Integer.to_string(param)
  end

  def convert(param, _, _) when is_boolean(param) do
    case param do
      true -> 1
      false -> 0
    end
  end

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

  def convert({:json, param}, _, _) do
    param
  end

  def convert(param, _, _) do
    param
  end
end
