defmodule Pillar do
  @moduledoc """
  """
  alias Pillar.Connection
  alias Pillar.HttpClient
  alias Pillar.QueryBuilder
  alias Pillar.ResponseParser

  def query(%Connection{} = connection, query, params \\ %{}) do
    final_sql = QueryBuilder.build(query, params) <> "\n FORMAT JSON"

    connection
    |> Connection.url_from_connection()
    |> HttpClient.post(final_sql)
    |> ResponseParser.parse()
  end

  defmacro __using__(connection_string: connection_string, name: name) do
    quote do
      use GenServer

      def start_link(_opts \\ nil) do
        GenServer.start_link(__MODULE__, unquote(connection_string), name: unquote(name))
      end

      def query(sql, params \\ %{}) do
        GenServer.call(unquote(name), {sql, params})
      end

      def async_query(sql, params \\ %{}) do
        GenServer.cast(unquote(name), {sql, params})
      end

      def init(connection_string) do
        {:ok, Connection.new(connection_string)}
      end

      def handle_call({query, params}, _from, state) do
        {:ok, result} = Pillar.query(state, query, params)
        {:reply, {:ok, result}, state}
      end

      def handle_cast({query, params}, state) do
        {:ok, _result} = Pillar.query(state, query, params)
        {:noreply, state}
      end
    end
  end
end
