defmodule Pillar.QueryBuilder do
  alias Pillar.TypeConvert.ToClickhouse

  def build(query, params) when is_map(params) do
    original_query = query

    Enum.reduce(params, original_query, fn {param_name, value}, query_with_params ->
      String.replace(query_with_params, "{#{param_name}}", ToClickhouse.convert(value))
    end)
  end
end
