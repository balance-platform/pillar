defmodule Pillar do
  @moduledoc """
  Elixir client for [ClickHouse](https://clickhouse.tech/), a fast open-source
  Online Analytical Processing (OLAP) database management system.

  ## Overview

  Pillar provides a straightforward way to interact with ClickHouse databases from Elixir,
  supporting both direct connections and connection pools. It handles query building, 
  parameter substitution, and response parsing.

  The library offers the following core features:
  - Direct connection to ClickHouse servers
  - Connection pooling for improved performance
  - Synchronous and asynchronous query execution
  - Structured data insertion
  - Parameter substitution
  - Query result parsing
  - Migration support

  ## Direct Usage

  For simple usage with a direct connection:

  ```elixir
  # Create a connection
  conn = Pillar.Connection.new("http://user:password@localhost:8123/database")

  # Execute a query with parameter substitution
  sql = "SELECT count(*) FROM users WHERE lastname = {lastname}"
  params = %{lastname: "Smith"}

  {:ok, result} = Pillar.query(conn, sql, params)
  # => [%{"count(*)" => 347}]
  ```

  ## Connection Pool Usage

  For production applications, using a connection pool is recommended:

  ```elixir
  defmodule MyApp.ClickHouse do
    use Pillar,
      connection_strings: [
        "http://user:password@host-1:8123/database",
        "http://user:password@host-2:8123/database"
      ],
      name: __MODULE__,
      pool_size: 15
  end

  # Start the connection pool
  MyApp.ClickHouse.start_link()

  # Execute queries using the pool
  {:ok, result} = MyApp.ClickHouse.select("SELECT * FROM users WHERE id = {id}", %{id: 123})
  ```

  ## Asynchronous Operations

  For non-blocking inserts:

  ```elixir
  # Using direct connection
  Pillar.async_insert(conn, "INSERT INTO events (user_id, event) VALUES ({user_id}, {event})", %{
    user_id: 42,
    event: "login"
  })

  # Using connection pool
  MyApp.ClickHouse.async_insert("INSERT INTO events (user_id, event) VALUES ({user_id}, {event})", %{
    user_id: 42,
    event: "login"
  })
  ```
  """

  alias Pillar.Connection
  alias Pillar.HttpClient
  alias Pillar.QueryBuilder
  alias Pillar.ResponseParser
  alias Pillar.Util

  @default_timeout_ms 5_000

  @doc """
  Executes an INSERT statement against a ClickHouse database.

  ## Parameters

  - `connection` - A `Pillar.Connection` struct representing the database connection
  - `query` - The SQL query string with optional parameter placeholders in curly braces `{param}`
  - `params` - A map of parameters to be substituted in the query (default: `%{}`)
  - `options` - A map of options to customize the request (default: `%{}`)

  ## Options

  - `:timeout` - Request timeout in milliseconds (default: `5000`)
  - Other options are passed to the connection's URL builder

  ## Returns

  - `{:ok, result}` on success
  - `{:error, reason}` on failure

  ## Examples

  ```elixir
  Pillar.insert(conn, "INSERT INTO users (name, email) VALUES ({name}, {email})", %{
    name: "John Doe",
    email: "john@example.com"
  })
  ```
  """
  def insert(%Connection{} = connection, query, params \\ %{}, options \\ %{}) do
    final_sql = QueryBuilder.query(query, params)
    execute_sql(connection, final_sql, options)
  end

  @doc """
  Inserts data into a specified table, automatically generating the INSERT statement.

  This function allows inserting one record (as a map) or multiple records (as a list of maps)
  into a ClickHouse table without having to manually construct the SQL INSERT statement.

  ## Parameters

  - `connection` - A `Pillar.Connection` struct representing the database connection
  - `table_name` - The name of the table to insert data into
  - `record_or_records` - A map or list of maps representing the data to insert
  - `options` - A map of options to customize the request (default: `%{}`)

  ## Options

  - `:timeout` - Request timeout in milliseconds (default: `5000`)
  - `:query_options` - Options for the query builder (e.g., `%{format: :json}`)

  ## Returns

  - `{:ok, result}` on success
  - `{:error, reason}` on failure

  ## Examples

  Single record:
  ```elixir
  Pillar.insert_to_table(conn, "users", %{
    name: "John Doe",
    email: "john@example.com",
    created_at: DateTime.utc_now()
  })
  ```

  Multiple records:
  ```elixir
  Pillar.insert_to_table(conn, "users", [
    %{name: "John Doe", email: "john@example.com"},
    %{name: "Jane Smith", email: "jane@example.com"}
  ])
  ```
  """
  def insert_to_table(
        %Connection{version: version} = connection,
        table_name,
        record_or_records,
        options \\ %{}
      )
      when is_binary(table_name) do
    query_options = Map.get(options, :query_options, %{})

    final_sql =
      QueryBuilder.insert_to_table(table_name, record_or_records, version, query_options)

    options =
      if Util.has_input_format_json_read_numbers_as_strings?(version) do
        Map.put(options, :input_format_json_read_numbers_as_strings, true)
      else
        options
      end

    execute_sql(connection, final_sql, options)
  end

  @doc """
  Executes an arbitrary SQL query against a ClickHouse database.

  This function can be used for any type of query (SELECT, CREATE, ALTER, etc.)
  but doesn't format the response as JSON. For SELECT queries with formatted 
  results, consider using `select/4` instead.

  ## Parameters

  - `connection` - A `Pillar.Connection` struct representing the database connection
  - `query` - The SQL query string with optional parameter placeholders in curly braces `{param}`
  - `params` - A map of parameters to be substituted in the query (default: `%{}`)
  - `options` - A map of options to customize the request (default: `%{}`)

  ## Options

  - `:timeout` - Request timeout in milliseconds (default: `5000`)
  - Other options are passed to the connection's URL builder

  ## Returns

  - `{:ok, result}` on success
  - `{:error, reason}` on failure

  ## Examples

  ```elixir
  Pillar.query(conn, "CREATE TABLE users (id UInt64, name String, email String) ENGINE = MergeTree() ORDER BY id")

  Pillar.query(conn, "ALTER TABLE users ADD COLUMN created_at DateTime")
  ```
  """
  def query(%Connection{} = connection, query, params \\ %{}, options \\ %{}) do
    final_sql = QueryBuilder.query(query, params)
    execute_sql(connection, final_sql, options)
  end

  @doc """
  Executes a SELECT query and returns the results in a structured format.

  This function appends 'FORMAT JSON' to the query, which makes ClickHouse return
  the results in JSON format, which are then parsed into Elixir data structures.

  ## Parameters

  - `connection` - A `Pillar.Connection` struct representing the database connection
  - `query` - The SQL query string with optional parameter placeholders in curly braces `{param}`
  - `params` - A map of parameters to be substituted in the query (default: `%{}`)
  - `options` - A map of options to customize the request (default: `%{}`)

  ## Options

  - `:timeout` - Request timeout in milliseconds (default: `5000`)
  - Other options are passed to the connection's URL builder

  ## Returns

  - `{:ok, result}` on success, where result is a list of maps representing rows
  - `{:error, reason}` on failure

  ## Examples

  ```elixir
  {:ok, users} = Pillar.select(conn, 
    "SELECT id, name, email FROM users WHERE signup_date > {date} LIMIT {limit}", 
    %{date: "2023-01-01", limit: 100}
  )

  # users is a list of maps like:
  # [
  #   %{"id" => 1, "name" => "John Doe", "email" => "john@example.com"},
  #   %{"id" => 2, "name" => "Jane Smith", "email" => "jane@example.com"}
  # ]
  ```
  """
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

  @doc """
  Async version of `insert/4` that doesn't wait for a response.

  This function sends an INSERT query to ClickHouse but doesn't wait for a response,
  making it suitable for fire-and-forget operations where you don't need to confirm
  the result. Available only when using connection pools through the `use Pillar` macro.
  """
  def async_insert(%Connection{} = _connection, _query, _params \\ %{}, _options \\ %{}) do
    raise "async_insert/4 is only available through a connection pool created with `use Pillar`"
  end

  @doc """
  Async version of `insert_to_table/4` that doesn't wait for a response.

  This function inserts data into a specified table but doesn't wait for a response,
  making it suitable for fire-and-forget operations where you don't need to confirm
  the result. Available only when using connection pools through the `use Pillar` macro.
  """
  def async_insert_to_table(
        %Connection{} = _connection,
        _table_name,
        _record_or_records,
        _options \\ %{}
      ) do
    raise "async_insert_to_table/4 is only available through a connection pool created with `use Pillar`"
  end

  @doc """
  Async version of `query/4` that doesn't wait for a response.

  This function sends a query to ClickHouse but doesn't wait for a response,
  making it suitable for fire-and-forget operations where you don't need to confirm
  the result. Available only when using connection pools through the `use Pillar` macro.
  """
  def async_query(%Connection{} = _connection, _query, _params \\ %{}, _options \\ %{}) do
    raise "async_query/4 is only available through a connection pool created with `use Pillar`"
  end

  @doc """
  Defines a ClickHouse connection pool module.

  This macro sets up a module that manages a pool of ClickHouse connections.
  The generated module provides functions to execute queries against the connection pool,
  handling connection acquisition and release automatically.

  ## Options

  - `:connection_strings` - Required. A list of ClickHouse connection URLs
  - `:name` - Optional. The name of the pool (defaults to "PillarPool")
  - `:pool_size` - Optional. The number of connections to maintain (defaults to 10)
  - `:pool_timeout` - Optional. Timeout for acquiring a connection from the pool (defaults to 5000ms)
  - `:timeout` - Optional. Default query timeout (defaults to 5000ms)

  ## Generated Functions

  The macro generates the following functions in the module:

  - `start_link/1` - Starts the connection pool
  - `select/3` - Executes a SELECT query with JSON formatting
  - `query/3` - Executes an arbitrary SQL query
  - `insert/3` - Executes an INSERT statement
  - `insert_to_table/3` - Inserts data into a specified table
  - `async_query/3` - Asynchronously executes a query
  - `async_insert/3` - Asynchronously executes an INSERT statement
  - `async_insert_to_table/3` - Asynchronously inserts data into a specified table

  ## Example

  ```elixir
  defmodule MyApp.ClickHouse do
    use Pillar,
      connection_strings: [
        "http://user:password@host-1:8123/database",
        "http://user:password@host-2:8123/database"
      ],
      name: __MODULE__,
      pool_size: 15,
      pool_timeout: 10_000,
      timeout: 30_000
  end
  ```
  """
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
