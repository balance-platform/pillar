defmodule Pillar.Bulk.Helper do
  @moduledoc """
  Just functions, which should be private, but need to be tested
  """

  def columns(pool_mpdule, table_name) when is_atom(pool_mpdule) do
    {:ok, results} =
      pool_mpdule.select(
        "SELECT name FROM system.columns WHERE table = {table_name}",
        %{
          table_name: table_name
        }
      )

    Enum.flat_map(results, &Map.values/1)
  end

  def generate_bulk_insert_query(table_name, columns, values) do
    cols_sql = "(" <> Enum.join(columns, ", ") <> ")"

    prepared_values =
      values
      |> Enum.with_index()
      |> Enum.map(fn {map, idx} ->
        map = map_fields_to_string(map)

        Enum.map(columns, fn column ->
          {column <> "_" <> to_string(idx), Map.get(map, column)}
        end)
      end)

    values_sql =
      prepared_values
      |> Enum.map(&values_to_pillar_brace_names/1)
      |> Enum.join(", ")

    sql_strings = [
      "INSERT INTO",
      table_name,
      cols_sql,
      "FORMAT Values",
      values_sql
    ]

    {Enum.join(sql_strings, " "), make_flat_map(prepared_values)}
  end

  defp make_flat_map(list_of_list_of_tuples) do
    list_of_list_of_tuples
    |> Enum.map(&Map.new/1)
    |> Enum.reduce(%{}, fn el, acc ->
      Map.merge(acc, el)
    end)
  end

  defp map_fields_to_string(map) do
    Enum.map(map, fn {key, value} ->
      {to_string(key), value}
    end)
    |> Map.new()
  end

  defp values_to_pillar_brace_names(list) when is_list(list) do
    fields_string =
      list
      |> Enum.map(fn {field_name, _value} -> field_name end)
      |> Enum.map(fn name -> "{" <> name <> "}" end)
      |> Enum.join(", ")

    "(" <> fields_string <> ")"
  end
end
