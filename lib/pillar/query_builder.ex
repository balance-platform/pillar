defmodule Pillar.QueryBuilder do
  @moduledoc false
  alias Pillar.TypeConvert.ToClickhouse
  alias Pillar.TypeConvert.ToClickhouseJson

  def query(query, params) when is_map(params) do
    case Enum.empty?(params) do
      true ->
        query

      false ->
        original_query = query
        prepare_params = Enum.map(params, fn {k, v} -> {"{#{k}}", v} end) |> Enum.into(%{})

        String.replace(original_query, Map.keys(prepare_params), fn pattern ->
          ToClickhouse.convert(prepare_params[pattern])
        end)
    end
  end

  def insert_to_table(table_name, records, db_version \\ nil, query_options \\ %{})

  def insert_to_table(table_name, record, db_version, query_options) when is_map(record) do
    converted_value =
      convert_values_to_clickhouse_for_json_insert(record, db_version, query_options)

    generate_json_insert_query(table_name, List.wrap(converted_value))
  end

  def insert_to_table(table_name, records, db_version, query_options) when is_list(records) do
    converted_values =
      Enum.map(
        records,
        &convert_values_to_clickhouse_for_json_insert(&1, db_version, query_options)
      )

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

  defp convert_values_to_clickhouse_for_json_insert(map, db_version, query_options) do
    map
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Enum.map(fn {key, value} ->
      {key, ToClickhouseJson.convert(value, db_version, query_options)}
    end)
    |> Map.new()
  end
end
