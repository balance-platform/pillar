defmodule Pillar do
  alias Pillar.Connection
  alias Pillar.HttpClient
  alias Pillar.QueryBuilder
  alias Pillar.ResponseParser

  def query(%Connection{} = connection, query, params \\ %{}) do
    final_sql = QueryBuilder.build(query, params) <> " FORMAT JSON"

    connection
    |> Connection.url_from_connection()
    |> HttpClient.post(final_sql)
    |> ResponseParser.parse()
  end
end
