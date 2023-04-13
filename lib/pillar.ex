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

    connection
    |> Connection.url_from_connection(options)
    |> HttpClient.post(final_sql, timeout: timeout)
    |> ResponseParser.parse()
  end

  defmacro __using__(options) do
    quote do
      use GenServer
      import Supervisor.Spec

      defp connection_strings do
        Keyword.get(unquote(options), :connection_strings)
      end

      defp name do
        Keyword.get(unquote(options), :name, "PillarPool")
      end

      defp pool_size() do
        Keyword.get(unquote(options), :pool_size, 10)
      end

      defp pool_timeout() do
        Keyword.get(unquote(options), :pool_timeout, 5_000)
      end

      defp timeout() do
        Keyword.get(unquote(options), :timeout, 5_000)
      end

      defp poolboy_config do
        [
          name: {:local, name()},
          worker_module: Pillar.Pool.Worker,
          size: pool_size(),
          max_overflow: Kernel.ceil(pool_size() * 0.3)
        ]
      end

      def start_link(_opts \\ nil) do
        children = [
          :poolboy.child_spec(:worker, poolboy_config(), connection_strings())
        ]

        opts = [strategy: :one_for_one, name: :"#{name()}.Supervisor"]
        Supervisor.start_link(children, opts)
      end

      def init(init_arg) do
        {:ok, init_arg}
      end

      def select(sql, params \\ %{}, options \\ %{timeout: timeout()}) do
        :poolboy.transaction(
          name(),
          fn pid -> GenServer.call(pid, {:select, sql, params, options}, :infinity) end,
          pool_timeout()
        )
      end

      def query(sql, params \\ %{}, options \\ %{timeout: timeout()}) do
        :poolboy.transaction(
          name(),
          fn pid -> GenServer.call(pid, {:query, sql, params, options}, :infinity) end,
          pool_timeout()
        )
      end

      def async_query(sql, params \\ %{}, options \\ %{timeout: timeout()}) do
        :poolboy.transaction(
          name(),
          fn pid -> GenServer.cast(pid, {:query, sql, params, options}) end,
          pool_timeout()
        )
      end

      def insert(sql, params \\ %{}, options \\ %{timeout: timeout()}) do
        :poolboy.transaction(
          name(),
          fn pid -> GenServer.call(pid, {:insert, sql, params, options}, :infinity) end,
          pool_timeout()
        )
      end

      def async_insert(sql, params \\ %{}, options \\ %{timeout: timeout()}) do
        :poolboy.transaction(
          name(),
          fn pid -> GenServer.cast(pid, {:insert, sql, params, options}) end,
          pool_timeout()
        )
      end

      def insert_to_table(
            table_name,
            record_or_records \\ %{},
            options \\ %{timeout: timeout()}
          ) do
        :poolboy.transaction(
          name(),
          fn pid ->
            GenServer.call(
              pid,
              {:insert_to_table, table_name, record_or_records, options},
              :infinity
            )
          end,
          pool_timeout()
        )
      end

      def async_insert_to_table(
            table_name,
            record_or_records \\ %{},
            options \\ %{timeout: timeout()}
          ) do
        :poolboy.transaction(
          name(),
          fn pid ->
            GenServer.cast(pid, {:insert_to_table, table_name, record_or_records, options})
          end,
          pool_timeout()
        )
      end
    end
  end
end
