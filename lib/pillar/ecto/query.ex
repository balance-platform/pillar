defmodule Pillar.Ecto.Query do
  alias Pillar.Ecto.QueryBuilder

  @type t :: %__MODULE__{
          name: iodata,
          param_count: integer,
          params: iodata | nil,
          columns: [String.t()] | nil
        }

  defstruct name: nil,
            statement: "",
            type: :select,
            params: [],
            param_count: 0,
            columns: []

  def new(statement) do
    %__MODULE__{statement: statement}
    |> DBConnection.Query.parse([])
  end

  @spec all(query :: Ecto.Query.t()) :: String.t()
  def all(query) do
    sources = QueryBuilder.create_names(query)

    # We now extract all parameters in the query
    # this should be in the same order as we join the query down below together

    all_params =
      query.wheres
      |> Enum.reduce([], fn elem, acc -> QueryBuilder.param_extractor(elem, sources, acc) end)
      |> Enum.reverse()

    {select_distinct, order_by_distinct} = QueryBuilder.distinct(query.distinct, sources, query)

    {from, all_params} = QueryBuilder.from(query, sources, all_params)
    {select, all_params} = QueryBuilder.select(query, select_distinct, sources, all_params)
    # join = QueryBuilder.join(query, sources)
    {where, all_params} = QueryBuilder.where(query, sources, all_params)
    {group_by, all_params} = QueryBuilder.group_by(query, sources, all_params)
    {having, all_params} = QueryBuilder.having(query, sources, all_params)
    {order_by, all_params} = QueryBuilder.order_by(query, order_by_distinct, sources, all_params)
    {limit, _all_params} = QueryBuilder.limit(query, sources, all_params)

    res = [select, from, where, group_by, having, order_by, limit]

    IO.iodata_to_binary(res)
  end

  def insert(_prefix, _table, _header, _rows, _on_conflict, _returning),
    do: raise("Not supported")

  def update(_prefix, _table, _fields, _filters, _returning), do: raise("Not supported")

  def delete(_prefix, _table, _filters, _returning), do: raise("Not supported")

  def update_all(_query, _prefix \\ nil), do: raise("Not supported")

  def delete_all(_query), do: raise("Not supported")

  defmacro any_ch(field) do
    quote do
      fragment("any(?)", unquote(field))
    end
  end

  defmacro uniq(field) do
    quote do
      fragment("uniq(?)", unquote(field))
    end
  end

  defmacro stddevPop(field) do
    quote do
      fragment("stddevPop(?)", unquote(field))
    end
  end
end

defimpl DBConnection.Query, for: Pillar.Ecto.Query do
  def parse(%{statement: statement, params: params} = query, _opts) do
    params =
      Regex.scan(~r/\{\w+_\d:\w+\}*/, statement)
      |> List.flatten()
      |> Enum.map(fn param ->
        [name, _] = Regex.replace(~r/({|})/, param, "") |> String.split(":")
        name
      end)
      |> Enum.zip(params)
      |> Enum.map(fn {name, value} ->
        "param_#{name}=#{value}"
      end)

    %{query | param_count: length(params), params: params}
  end

  def describe(query, _opts) do
    query
  end

  def encode(%{type: :insert}, _params, _opts), do: raise("Not supported")

  def encode(%{statement: query_part}, _params, _opts) do
    query_part
  end

  def decode(_query, result, _opts) do
    result
  end
end

defimpl String.Chars, for: Pillar.Ecto.Query do
  def to_string(%Pillar.Ecto.Query{statement: statement}) do
    IO.iodata_to_binary(statement)
  end
end
