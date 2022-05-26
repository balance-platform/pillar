defmodule Pillar do
  @moduledoc false

  alias Pillar.Connection
  alias Pillar.HttpClient
  alias Pillar.QueryBuilder
  alias Pillar.ResponseParser

  @default_timeout_ms 5_000

  def insert(%Connection{} = connection, query, params \\ %{}, options \\ %{}) do
    final_sql = QueryBuilder.query(query, params)
    timeout = Map.get(options, :timeout, @default_timeout_ms)

    execute_sql(connection, final_sql, timeout)
  end

  def insert_to_table(%Connection{} = connection, table_name, record_or_records, options \\ %{})
      when is_binary(table_name) do
    final_sql = QueryBuilder.insert_to_table(table_name, record_or_records)
    timeout = Map.get(options, :timeout, @default_timeout_ms)

    execute_sql(connection, final_sql, timeout)
  end

  def query(%Connection{} = connection, query, params \\ %{}, options \\ %{}) do
    final_sql = QueryBuilder.query(query, params)
    timeout = Map.get(options, :timeout, @default_timeout_ms)

    execute_sql(connection, final_sql, timeout)
  end

  def select(%Connection{} = connection, query, params \\ %{}, options \\ %{}) do
    final_sql = QueryBuilder.query(query, params) <> "\n FORMAT JSON"
    timeout = Map.get(options, :timeout, @default_timeout_ms)

    execute_sql(connection, final_sql, timeout)
  end

  defp execute_sql(connection, final_sql, timeout) do
    connection
    |> Connection.url_from_connection()
    |> HttpClient.post(final_sql, timeout: timeout)
    |> ResponseParser.parse()
  end

  defmacro __using__(options) do
    quote bind_quoted: [options: options] do
      use GenServer
      import Supervisor.Spec

      connection_strings = Keyword.get(options, :connection_strings)
      name = Keyword.get(options, :name)
      pool_size = Keyword.get(options, :pool_size)

      @pool_timeout 5_000
      pool_timeout = Keyword.get(options, :pool_timeout, @pool_timeout)

      @timeout 5_000
      timeout = Keyword.get(options, :timeout, @timeout)

      defp poolboy_config do
        [
          name: {:local, unquote(name)},
          worker_module: Pillar.Pool.Worker,
          size: unquote(pool_size),
          max_overflow: Kernel.ceil(unquote(pool_size) * 0.3)
        ]
      end

      def start_link(_opts \\ nil) do
        children = [
          :poolboy.child_spec(:worker, poolboy_config(), unquote(connection_strings))
        ]

        opts = [strategy: :one_for_one, name: :"#{unquote(name)}.Supervisor"]
        Supervisor.start_link(children, opts)
      end

      def init(init_arg) do
        {:ok, init_arg}
      end

      def select(sql, params \\ %{}, options \\ %{timeout: unquote(timeout)}) do
        :poolboy.transaction(
          unquote(name),
          fn pid -> GenServer.call(pid, {:select, sql, params, options}, :infinity) end,
          unquote(pool_timeout)
        )
      end

      def query(sql, params \\ %{}, options \\ %{timeout: unquote(timeout)}) do
        :poolboy.transaction(
          unquote(name),
          fn pid -> GenServer.call(pid, {:query, sql, params, options}, :infinity) end,
          unquote(pool_timeout)
        )
      end

      def async_query(sql, params \\ %{}, options \\ %{timeout: unquote(timeout)}) do
        :poolboy.transaction(
          unquote(name),
          fn pid -> GenServer.cast(pid, {:query, sql, params, options}) end,
          unquote(pool_timeout)
        )
      end

      def insert(sql, params \\ %{}, options \\ %{timeout: unquote(timeout)}) do
        :poolboy.transaction(
          unquote(name),
          fn pid -> GenServer.call(pid, {:insert, sql, params, options}, :infinity) end,
          unquote(pool_timeout)
        )
      end

      def async_insert(sql, params \\ %{}, options \\ %{timeout: unquote(timeout)}) do
        :poolboy.transaction(
          unquote(name),
          fn pid -> GenServer.cast(pid, {:insert, sql, params, options}) end,
          unquote(pool_timeout)
        )
      end

      def insert_to_table(
            table_name,
            record_or_records \\ %{},
            options \\ %{timeout: unquote(timeout)}
          ) do
        :poolboy.transaction(
          unquote(name),
          fn pid ->
            GenServer.call(
              pid,
              {:insert_to_table, table_name, record_or_records, options},
              :infinity
            )
          end,
          unquote(pool_timeout)
        )
      end

      def async_insert_to_table(
            table_name,
            record_or_records \\ %{},
            options \\ %{timeout: unquote(timeout)}
          ) do
        :poolboy.transaction(
          unquote(name),
          fn pid ->
            GenServer.cast(pid, {:insert_to_table, table_name, record_or_records, options})
          end,
          unquote(pool_timeout)
        )
      end
    end
  end
end
