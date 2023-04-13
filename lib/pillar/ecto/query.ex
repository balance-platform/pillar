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
    all_params = MapSet.new()

    IO.inspect(["query - all", query, query.sources, query.wheres])

    sources = QueryBuilder.create_names(query)
    IO.inspect(["sources", sources])
    {select_distinct, order_by_distinct} = QueryBuilder.distinct(query.distinct, sources, query)

    from = QueryBuilder.from(query, sources)
    select = QueryBuilder.select(query, select_distinct, sources)
    # join = QueryBuilder.join(query, sources)
    {where, all_params} = QueryBuilder.where(query, sources, all_params)
    {group_by, all_params} = QueryBuilder.group_by(query, sources, all_params)
    {having, all_params} = QueryBuilder.having(query, sources, all_params)
    {order_by, all_params} = QueryBuilder.order_by(query, order_by_distinct, sources, all_params)
    {limit, all_params} = QueryBuilder.limit(query, sources, all_params)

    res = [select, from, where, group_by, having, order_by, limit]

    IO.inspect(["END"])

    IO.iodata_to_binary(res)
  end

  def insert(_prefix, _table, _header, _rows, _on_conflict, _returning),
    do: raise("Not supported")

  def update(_prefix, _table, _fields, _filters, _returning), do: raise("Not supported")

  def delete(_prefix, _table, _filters, _returning), do: raise("Not supported")

  def update_all(_query, _prefix \\ nil), do: raise("Not supported")

  def delete_all(_query), do: raise("Not supported")
end

defimpl DBConnection.Query, for: Pillar.Ecto.Query do
  def parse(%{statement: statement} = query, _opts) do
    param_count =
      statement
      |> String.codepoints()
      |> Enum.count(fn s -> s == "?" end)

    %{query | param_count: param_count}
  end

  def describe(query, _opts) do
    query
  end

  def encode(%{type: :insert} = query, _params, _opts), do: raise("Not supported")

  def encode(%{statement: query_part}, params, _opts) do
    # TODO: ENCODE PARAMS?
    IO.inspect(["ENCODE QUERY", params])
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
