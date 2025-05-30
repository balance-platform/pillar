# Pillar

[![github.com](https://github.com/balance-platform/pillar/workflows/build/badge.svg?branch=master)](https://github.com/balance-platform/pillar/actions)
[![hex.pm](https://img.shields.io/badge/docs-hexpm-blue.svg)](https://hexdocs.pm/pillar)
[![hex.pm](https://img.shields.io/hexpm/v/pillar.svg)](https://hex.pm/packages/pillar)
[![hex.pm](https://img.shields.io/hexpm/dt/pillar.svg)](https://hex.pm/packages/pillar)
[![hex.pm](https://img.shields.io/hexpm/l/pillar.svg)](https://hex.pm/packages/pillar)
[![github.com](https://img.shields.io/github/last-commit/balance-platform/pillar.svg)](https://github.com/balance-platform/pillar/commits/master)

Elixir client for [ClickHouse](https://clickhouse.tech/), a fast open-source
Online Analytical Processing (OLAP) database management system.

## Table of Contents

- [Getting Started](#getting-started)
  - [Installation](#installation)
  - [Basic Usage](#basic-usage)
- [Features](#features)
  - [Direct Usage with connection structure](#direct-usage-with-connection-structure)
  - [Pool of workers](#pool-of-workers)
  - [Async insert](#async-insert)
  - [Buffer for periodical bulk inserts](#buffer-for-periodical-bulk-inserts)
  - [Migrations](#migrations)
  - [DateTime Timezones](#timezones)
  - [Switching between HTTP adapters](#http-adapters)
- [Configuration](#configuration)
  - [Connection Options](#connection-options)
  - [Pool Configuration](#pool-configuration)
  - [HTTP Adapters](#http-adapters)
- [Advanced Usage](#advanced-usage)
  - [Bulk Insert Strategies](#bulk-insert-strategies)
  - [Custom Type Conversions](#custom-type-conversions)
- [Troubleshooting](#troubleshooting)
  - [Common Issues](#common-issues)
  - [Performance Optimization](#performance-optimization)
- [Contribution](#contribution)

## Getting Started

### Installation

Add `pillar` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:pillar, "~> 0.39.0"}
  ]
end
```

### Basic Usage

Here's a simple example to get started with Pillar:

```elixir
# Create a direct connection
conn = Pillar.Connection.new("http://user:password@localhost:8123/database")

# Execute a SELECT query
{:ok, result} = Pillar.select(conn, "SELECT * FROM users LIMIT 10")

# Execute a parameterized query
{:ok, result} = Pillar.query(conn, 
  "SELECT * FROM users WHERE created_at > {min_date} LIMIT {limit}", 
  %{min_date: "2023-01-01", limit: 100}
)

# Insert data
{:ok, _} = Pillar.insert(conn, 
  "INSERT INTO events (user_id, event_type, created_at) VALUES ({user_id}, {event_type}, {created_at})",
  %{user_id: 123, event_type: "login", created_at: DateTime.utc_now()}
)
```

## Features

Pillar offers a comprehensive set of features for working with ClickHouse:

### Direct Usage with connection structure

The most straightforward way to use Pillar is by creating a direct connection to your ClickHouse server:

```elixir
# Create a connection to your ClickHouse server
conn = Pillar.Connection.new("http://user:password@localhost:8123/database")

# Parameters are passed in curly braces {} in the SQL query
# The map structure provides values for these parameters
sql = "SELECT count(*) FROM users WHERE lastname = {lastname}"

params = %{lastname: "Smith"}

{:ok, result} = Pillar.query(conn, sql, params)

result
#=> [%{"count(*)" => 347}]
```

You can also specify additional connection options:

```elixir
conn = Pillar.Connection.new(
  "http://user:password@localhost:8123/database",
  %{
    timeout: 30_000,  # Connection timeout in milliseconds
    pool_timeout: 5_000,  # Pool timeout in milliseconds
    request_timeout: 60_000  # Request timeout in milliseconds
  }
)
```

### Pool of workers

For production environments, using a connection pool is highly recommended. This approach provides:
- Efficient connection management
- Supervised workers
- Load balancing across multiple ClickHouse servers
- Better performance under high load

```elixir
defmodule ClickhouseMaster do
  use Pillar,
    connection_strings: [
      "http://user:password@host-master-1:8123/database",
      "http://user:password@host-master-2:8123/database"
    ],
    name: __MODULE__,
    pool_size: 15,
    pool_timeout: 10_000,  # Time to wait for a connection from the pool
    timeout: 30_000  # Default query timeout
end

# Start the connection pool as part of your supervision tree
ClickhouseMaster.start_link()

# Execute queries using the pool
{:ok, result} = ClickhouseMaster.select("SELECT * FROM users WHERE age > {min_age}", %{min_age: 21})
{:ok, _} = ClickhouseMaster.insert("INSERT INTO logs (message) VALUES ({message})", %{message: "User logged in"})
```

The pool automatically manages connection acquisition and release, and can handle multiple ClickHouse servers for load balancing and high availability.

### Async insert

Asynchronous inserts are useful for non-blocking operations when you don't need to wait for a response. This is particularly valuable for:
- Logging events
- Metrics collection
- Any high-volume insert operations where immediate confirmation isn't required

```elixir
# Using a connection pool (recommended approach)
ClickhouseMaster.async_insert(
  "INSERT INTO events (user_id, event, timestamp) VALUES ({user_id}, {event}, {timestamp})",
  %{
    user_id: user.id,
    event: "password_changed",
    timestamp: DateTime.utc_now()
  }
) # => :ok

# The request is sent and the function returns immediately without waiting for a response
```

Note: Async inserts are only available when using a connection pool created with `use Pillar`. If you attempt to use `Pillar.async_insert/4` directly with a connection structure, it will raise an error.

### Buffer for periodical bulk inserts

The bulk insert buffer feature allows you to collect records in memory and insert them in batches at specified intervals. This is highly efficient for:
- High-frequency event logging
- Metrics collection
- Any scenario where you need to insert many small records

This feature requires a [Pool of workers](#pool-of-workers) to be set up first.

```elixir
defmodule BulkToLogs do
  use Pillar.BulkInsertBuffer,
    # Reference to your Pillar connection pool
    pool: ClickhouseMaster,
    
    # Target table for inserts
    table_name: "logs",
    
    # How often to flush buffered records (seconds)
    # Default is 5 seconds if not specified
    interval_between_inserts_in_seconds: 5,
    
    # Optional error handler function
    on_errors: &__MODULE__.dump_to_file/2,
    
    # Maximum records to buffer before forcing a flush
    # Optional, defaults to 10000
    max_buffer_size: 5000

  @doc """
  Error handler that stores failed inserts into a file
  
  Parameters:
  - result: The error result from ClickHouse
  - records: The batch of records that failed to insert
  """
  def dump_to_file(_result, records) do
    timestamp = DateTime.utc_now() |> DateTime.to_string() |> String.replace(":", "-")
    directory = "bad_inserts"
    
    # Ensure the directory exists
    File.mkdir_p!(directory)
    
    # Write failed records to a file
    File.write("#{directory}/#{timestamp}.log", inspect(records, pretty: true))
  end

  @doc """
  Alternative error handler that attempts to retry failed inserts
  
  Note: Retrying can be risky in case of persistent errors
  """
  def retry_insert(_result, records) do
    # Add a short delay before retrying
    Process.sleep(1000)
    __MODULE__.insert(records)
  end
end
```

Usage example:

```elixir
# Records are buffered in memory until the flush interval
:ok = BulkToLogs.insert(%{value: "online", count: 133, datetime: DateTime.utc_now()})
:ok = BulkToLogs.insert(%{value: "online", count: 134, datetime: DateTime.utc_now()})
:ok = BulkToLogs.insert(%{value: "offline", count: 42, datetime: DateTime.utc_now()})

# All these records will be inserted in a single batch after the configured interval (5 seconds by default)
```

The `on_errors` parameter is a callback function that will be invoked if an error occurs during bulk insert. This is useful for:
- Logging failed inserts
- Writing failed records to a backup location
- Implementing custom retry logic

The callback receives two parameters:
1. The error result from ClickHouse
2. The batch of records that failed to insert

### Migrations

Pillar provides a migrations system to help you manage your ClickHouse database schema changes in a version-controlled manner. This feature is particularly useful for:
- Creating tables
- Modifying schema
- Ensuring consistent database setup across environments
- Tracking schema changes over time

#### Generating Migrations

Migrations can be generated with the mix task:

```bash
mix pillar.gen.migration create_events_table
```

This creates a new migration file in `priv/pillar_migrations` with a timestamp prefix, for example:
`priv/pillar_migrations/20250528120000_create_events_table.exs`

#### Basic Migration Structure

```elixir
defmodule Pillar.Migrations.CreateEventsTable do
  def up do
    """
    CREATE TABLE IF NOT EXISTS events (
      id UUID,
      user_id UInt64,
      event_type String,
      payload String,
      created_at DateTime
    ) ENGINE = MergeTree()
    ORDER BY (created_at, id)
    """
  end

  # Optional: Implement a down function for rollbacks
  def down do
    "DROP TABLE IF EXISTS events"
  end
end
```

#### Multi-Statement Migrations

For complex scenarios where you need to execute multiple statements in a single migration, return a list of strings:

```elixir
defmodule Pillar.Migrations.CreateMultipleTables do
  def up do
    # For multi-statement migrations, return a list of strings
    [
      """
      CREATE TABLE IF NOT EXISTS events (
        id UUID,
        user_id UInt64,
        event_type String,
        created_at DateTime
      ) ENGINE = MergeTree()
      ORDER BY (created_at, id)
      """,
      
      """
      CREATE TABLE IF NOT EXISTS event_metrics (
        date Date,
        event_type String,
        count UInt64
      ) ENGINE = SummingMergeTree(count)
      ORDER BY (date, event_type)
      """
    ]
  end
end
```

You can also dynamically generate migrations:

```elixir
defmodule Pillar.Migrations.CreateShardedTables do
  def up do
    # Generate 5 sharded tables
    (0..4) |> Enum.map(fn i ->
      """
      CREATE TABLE IF NOT EXISTS events_shard_#{i} (
        id UUID,
        user_id UInt64,
        event_type String,
        created_at DateTime
      ) ENGINE = MergeTree()
      ORDER BY (created_at, id)
      """
    end)
  end
end
```

#### Running Migrations

To run migrations, create a mix task:

```elixir
defmodule Mix.Tasks.MigrateClickhouse do
  use Mix.Task
  
  @shortdoc "Runs ClickHouse migrations"
  
  def run(args) do
    # Start any necessary applications
    Application.ensure_all_started(:pillar)
    
    # Parse command line arguments if needed
    {opts, _, _} = OptionParser.parse(args, strict: [env: :string])
    env = Keyword.get(opts, :env, "dev")
    
    # Get connection details from your application config
    connection_string = Application.get_env(:my_project, String.to_atom("clickhouse_#{env}_url"))
    conn = Pillar.Connection.new(connection_string)
    
    # Run the migrations
    case Pillar.Migrations.migrate(conn) do
      :ok -> 
        Mix.shell().info("Migrations completed successfully")
      {:error, reason} -> 
        Mix.shell().error("Migration failed: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end
end
```

Then run the migrations with:

```bash
mix migrate_clickhouse
# Or with environment specification:
mix migrate_clickhouse --env=prod
```

#### Migration Tracking

Pillar automatically tracks applied migrations in a special table named `pillar_migrations` in your ClickHouse database. This table is created automatically and contains:
- The migration version (derived from the timestamp)
- The migration name
- When the migration was applied

### Timezones

Pillar supports timezone-aware DateTime operations when working with ClickHouse. This is particularly important when:
- Storing and retrieving DateTime values
- Performing date/time calculations across different time zones
- Ensuring consistent timestamp handling

To enable timezone support:

1. Add the `tzdata` dependency to your project:

```elixir
defp deps do
  [
    {:pillar, "~> 0.39.0"},
    {:tzdata, "~> 1.1"}
  ]
end
```

2. Configure Elixir to use the Tzdata timezone database:

```elixir
# In your config/config.exs
config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase
```

3. Use timezone-aware DateTime functions in your code:

```elixir
# Create a timezone-aware DateTime
datetime = DateTime.from_naive!(~N[2023-01-15 10:30:00], "Europe/Berlin")

# Insert it into ClickHouse
Pillar.insert(conn, 
  "INSERT INTO events (id, timestamp) VALUES ({id}, {timestamp})",
  %{id: 123, timestamp: datetime}
)
```

For more details on DateTime and timezone handling in Elixir, see the [official documentation](https://hexdocs.pm/elixir/1.12/DateTime.html#module-time-zone-database).

## Configuration

### Connection Options

When creating a new connection with `Pillar.Connection.new/2`, you can specify various options (parameters):

```elixir
Pillar.Connection.new(
  "http://user:password@localhost:8123/database",
    # Params take precedence over URI string

    # Authentication options
    user: "default",             # Override username in URL
    password: "secret",          # Override password in URL
    
    # Timeout options
    timeout: 30_000,             # Connection timeout in milliseconds
    
    # ClickHouse specific options
    database: "my_database",     # Override database in URL
    default_format: "JSON",      # Default response format
    
    # Query execution options
    max_execution_time: 60,      # Maximum query execution time in seconds
    max_memory_usage: 10000000,  # Maximum memory usage for query in bytes
)
```

### Pool Configuration

When using a connection pool with `use Pillar`, you can configure the following options:

```elixir
defmodule MyApp.ClickHouse do
  use Pillar,
    # List of ClickHouse servers for load balancing and high availability
    connection_strings: [
      "http://user:password@clickhouse-1:8123/database",
      "http://user:password@clickhouse-2:8123/database"
    ],
    
    # Pool name (defaults to module name if not specified)
    name: __MODULE__,
    
    # Number of connections to maintain in the pool (default: 10)
    pool_size: 15,
    
    # Maximum overflow connections (calculated as pool_size * 0.3 by default)
    max_overflow: 5,
    
    # Time to wait when acquiring a connection from the pool in ms (default: 5000)
    pool_timeout: 10_000,
    
    # Default query timeout in ms (default: 5000)
    timeout: 30_000
end
```

### HTTP Adapters

Pillar provides multiple HTTP adapters for communicating with ClickHouse:

1. **TeslaMintAdapter** (default): Uses Tesla with Mint HTTP client
2. **HttpcAdapter**: Uses Erlang's built-in `:httpc` module

If you encounter issues with the default adapter, you can switch to an alternative:

```elixir
# In your config/config.exs
config :pillar, Pillar.HttpClient, http_adapter: Pillar.HttpClient.HttpcAdapter
```

You can also implement your own HTTP adapter by creating a module that implements the `post/3` function and returns either a `%Pillar.HttpClient.Response{}` or a `%Pillar.HttpClient.TransportError{}` struct:

```elixir
defmodule MyApp.CustomHttpAdapter do
  @behaviour Pillar.HttpClient.Adapter

  @impl true
  def post(url, body, options) do
    # Implement your custom HTTP client logic
    # ...
    
    # Return a response struct
    %Pillar.HttpClient.Response{
      body: response_body,
      status: 200,
      headers: [{"content-type", "application/json"}]
    }
  end
end

# Configure Pillar to use your custom adapter
config :pillar, Pillar.HttpClient, http_adapter: MyApp.CustomHttpAdapter
```

## Advanced Usage

### Bulk Insert Strategies

Pillar provides several strategies for handling bulk inserts:

1. **Direct batch insert**: Insert multiple records in a single query
   ```elixir
   records = [
     %{id: 1, name: "Alice", score: 85},
     %{id: 2, name: "Bob", score: 92},
     %{id: 3, name: "Charlie", score: 78}
   ]
   
   Pillar.insert_to_table(conn, "students", records)
   ```

2. **Buffered inserts**: Use `Pillar.BulkInsertBuffer` for timed batch processing
   ```elixir
   # Define a buffer module as shown in the Buffer section
   
   # Then insert records that will be buffered and flushed periodically
   StudentMetricsBuffer.insert(%{student_id: 123, metric: "login", count: 1})
   ```

3. **Async inserts**: Use `async_insert` for fire-and-forget operations
   ```elixir
   ClickHouseMaster.async_insert_to_table("event_logs", %{
     event: "page_view",
     user_id: 42,
     timestamp: DateTime.utc_now()
   })
   ```

### Custom Type Conversions

Pillar handles type conversions between Elixir and ClickHouse automatically, but you can extend or customize this behavior:

```elixir
# Convert a custom Elixir struct to a ClickHouse-compatible format
defimpl Pillar.TypeConvert.ToClickHouse, for: MyApp.User do
  def convert(user) do
    %{
      id: user.id,
      name: user.full_name,
      email: user.email,
      created_at: DateTime.to_iso8601(user.inserted_at)
    }
  end
end
```

## Troubleshooting

### Common Issues

#### Connection Timeouts

If you experience connection timeouts, consider:

1. Increasing the timeout values:
   ```elixir
   conn = Pillar.Connection.new(url, %{timeout: 30_000})
   ```

2. Checking network connectivity between your application and ClickHouse

3. Verifying ClickHouse server is running and accepting connections:
   ```bash
   curl http://clickhouse-server:8123/ping
   ```

#### Memory Limitations

For large queries that consume significant memory:

1. Add query settings to limit memory usage:
   ```elixir
   Pillar.query(conn, "SELECT * FROM huge_table", %{}, %{
     max_memory_usage: 10000000000,  # 10GB
     max_execution_time: 300         # 5 minutes
   })
   ```

2. Consider using streaming queries (with FORMAT CSV or TabSeparated) for very large result sets

#### Bulk Insert Failures

If bulk inserts fail:

1. Check your error handler in the `BulkInsertBuffer` configuration
2. Verify data types match the table schema
3. Consider reducing batch sizes or increasing the interval between inserts

### Performance Optimization

1. **Use connection pooling**: Always use a connection pool in production environments

2. **Batch inserts**: Group multiple inserts into a single operation when possible

3. **Use async operations**: For high-volume inserts where immediate confirmation isn't necessary

4. **Query optimization**: Leverage ClickHouse's strengths:
   - Use proper table engines based on your query patterns
   - Ensure you have appropriate indices
   - Filter on columns used in the ORDER BY clause

5. **Connection reuse**: Avoid creating new connections for each query

## Contribution

Feel free to make a pull request. All contributions are appreciated!
