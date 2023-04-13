defmodule Pillar.Ecto.Connection do
  alias Pillar.Ecto.Query

  def child_spec(opts) do
    DBConnection.child_spec(Pillar.Ecto.ConnMod, opts)
  end

  def query(conn, query, params, _) when is_binary(query) do
    query = %Query{name: "", statement: query, params: params}
    execute(conn, query, [], [])
  end

  def prepare_execute(conn, name, prepared_query, params, options) do
    query = %Query{name: name, statement: prepared_query, params: params}

    case DBConnection.prepare_execute(conn, query, params, options) do
      {:ok, query, result} ->
        {:ok, %{query | statement: prepared_query}, result}

      {:error, error} ->
        raise error
    end
  end

  def execute(conn, query, params, options) do
    IO.inspect(["execute(conn, query, params, options)"])

    case DBConnection.prepare_execute(conn, query, params, options) do
      {:ok, _query, result} ->
        {:ok, result}

      {:error, error} ->
        raise error
    end
  end

  def to_constraints(_error), do: []

  def stream(_conn, _prepared, _params, _options), do: raise("not implemented")

  ## Queries
  def all(query) do
    IO.inspect(["#{__MODULE__} - all", query])
    Query.all(query)
  end

  def update_all(query, prefix \\ nil), do: Query.update_all(query, prefix)

  def delete_all(query), do: Query.delete_all(query)

  def insert(prefix, table, header, rows, on_conflict, returning),
    do: Query.insert(prefix, table, header, rows, on_conflict, returning)

  def update(prefix, table, fields, filters, returning),
    do: Query.update(prefix, table, fields, filters, returning)

  def delete(prefix, table, filters, returning),
    do: Query.delete(prefix, table, filters, returning)

  ## Migration
  def execute_ddl(_), do: raise("No")
end
