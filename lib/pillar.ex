defmodule Pillar do
  @moduledoc false

  alias Pillar.Connection
  alias Pillar.HttpClient
  alias Pillar.QueryBuilder
  alias Pillar.ResponseParser

  @default_timeout_ms 5_000

  def insert(%Connection{} = connection, query, params \\ %{}, options \\ %{}) do
    final_sql = QueryBuilder.query(query, params)
    execute_sql(connection, final_sql, options)
  end

  def insert_to_table(%Connection{} = connection, table_name, record_or_records, options \\ %{})
      when is_binary(table_name) do
    final_sql = QueryBuilder.insert_to_table(table_name, record_or_records)
    execute_sql(connection, final_sql, options)
  end

  def query(%Connection{} = connection, query, params \\ %{}, options \\ %{}) do
    final_sql = QueryBuilder.query(query, params)
    execute_sql(connection, final_sql, options)
  end

  def select(%Connection{} = connection, query, params \\ %{}, options \\ %{}) do
    final_sql = QueryBuilder.query(query, params) <> "\n FORMAT JSON"
    execute_sql(connection, final_sql, options)
  end

  defp execute_sql(connection, final_sql, options) do
    timeout = Map.get(options, :timeout, @default_timeout_ms)
    pool = Map.get(options, :pool, connection.pool)

    connection
    |> Connection.url_from_connection(options)
    |> HttpClient.post(final_sql, timeout: timeout, pool: pool)
    |> ResponseParser.parse()
  end

  defmacro __using__(options) do
    quote do
      use GenServer
      import Supervisor.Spec

      defp connection_strings do
        Keyword.get(unquote(options), :connection_strings)
      end

      defp get_connection do
        :ets.lookup_element(:pillar_finch_instances, __MODULE__, 2)
        |> Enum.random()
      end

      defp name do
        Keyword.get(unquote(options), :name, __MODULE__)
      end

      defp pool_size() do
        Keyword.get(unquote(options), :pool_size, 20)
      end

      defp timeout() do
        Keyword.get(unquote(options), :timeout, 5_000)
      end

      def start_link(_opts \\ nil) do
        finch_instance_name = :"#{to_string(name())}FinchInstance"

        children = [
          {Finch,
           name: finch_instance_name,
           pools: %{
             :default => [size: pool_size()]
           }}
        ]

        pools =
          connection_strings()
          |> Enum.map(
            &(Pillar.Connection.new(&1)
              |> Map.put(:pool, finch_instance_name))
          )

        :ets.insert(:pillar_finch_instances, {__MODULE__, pools})

        opts = [strategy: :one_for_one, name: name(), id: __MODULE__]
        Supervisor.start_link(children, opts)
      end

      def init(init_arg) do
        {:ok, init_arg}
      end

      def select(sql, params \\ %{}, options \\ %{timeout: timeout()}) do
        Pillar.select(get_connection(), sql, params, options)
      end

      def query(sql, params \\ %{}, options \\ %{timeout: timeout()}) do
        Pillar.query(get_connection(), sql, params, options)
      end

      @deprecated "Use Task.async/1 instead"
      def async_query(sql, params \\ %{}, options \\ %{timeout: timeout()}) do
        Task.async(fn ->
          Pillar.insert(get_connection(), sql, params, options)
        end)

        :ok
      end

      def insert(sql, params \\ %{}, options \\ %{timeout: timeout()}) do
        Pillar.insert(get_connection(), sql, params, options)
      end

      @deprecated "Use Task.async/1 instead"
      def async_insert(sql, params \\ %{}, options \\ %{timeout: timeout()}) do
        Task.async(fn ->
          Pillar.insert(get_connection(), sql, params, options)
        end)

        :ok
      end

      def insert_to_table(
            table_name,
            record_or_records \\ %{},
            options \\ %{timeout: timeout()}
          ) do
        Pillar.insert_to_table(get_connection(), table_name, record_or_records, options)
      end

      @deprecated "Use Task.async/1 instead"
      def async_insert_to_table(
            table_name,
            record_or_records \\ %{},
            options \\ %{timeout: timeout()}
          ) do
        Task.async(fn ->
          Pillar.insert_to_table(get_connection(), table_name, record_or_records, options)
        end)

        :ok
      end
    end
  end
end
