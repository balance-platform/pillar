defmodule Pillar.QueryBuilder do
  @moduledoc false
  alias Pillar.TypeConvert.ToClickhouse
  alias Pillar.TypeConvert.ToClickhouseJson

  def query(query, params) when is_map(params) do
    original_query = query

    Enum.reduce(params, original_query, fn {param_name, value}, query_with_params ->
      String.replace(query_with_params, "{#{param_name}}", ToClickhouse.convert(value))
    end)
  end

  def insert_to_table(table_name, record) when is_map(record) do
    converted_value = convert_values_to_clickhouse_for_json_insert(record)

    generate_json_insert_query(table_name, List.wrap(converted_value))
  end

  def insert_to_table(table_name, records) when is_list(records) do
    converted_values = Enum.map(records, &convert_values_to_clickhouse_for_json_insert/1)

    generate_json_insert_query(table_name, converted_values)
  end

  defp generate_json_insert_query(table_name, records) do
    sql_strings = [
      "INSERT INTO",
      table_name,
      "FORMAT JSONEachRow",
      Enum.join(Enum.map(records, &Jason.encode!/1), " ")
    ]

    Enum.join(sql_strings, "\n")
  end

  defp convert_values_to_clickhouse_for_json_insert(map) do
    map
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Enum.map(fn {key, value} ->
      {key, ToClickhouseJson.convert(value)}
    end)
    |> Map.new()
  end
end
