# Connection Pool

For production environments, using a connection pool is highly recommended. Pillar makes it easy to create and manage a pool of connections to your ClickHouse servers.

## Benefits of Connection Pooling

- **Performance**: Reusing existing connections reduces overhead
- **Resource Management**: Controls the number of concurrent connections
- **Load Balancing**: Distributes queries across multiple ClickHouse servers
- **Fault Tolerance**: Handles server failures gracefully
- **Supervision**: Automatically reconnects failed connections

## Setting Up a Connection Pool

To create a connection pool, define a module that uses Pillar:

```elixir
defmodule MyApp.ClickHouse do
  use Pillar,
    connection_strings: [
      "http://user:password@clickhouse-1:8123/database",
      "http://user:password@clickhouse-2:8123/database"
    ],
    name: __MODULE__,
    pool_size: 15
end
```

Then start the connection pool, typically in your application's supervision tree:

```elixir
# In your application.ex
def start(_type, _args) do
  children = [
    # Other children...
    MyApp.ClickHouse
  ]
  
  opts = [strategy: :one_for_one, name: MyApp.Supervisor]
  Supervisor.start_link(children, opts)
end
```

## Configuration Options

When setting up a connection pool, you can configure the following options:

| Option | Description | Default |
|--------|-------------|---------|
| `connection_strings` | List of ClickHouse server URLs | (required) |
| `name` | Name of the pool | Module name |
| `pool_size` | Number of connections to maintain | 10 |
| `pool_timeout` | Time to wait for a connection from the pool (ms) | 5000 |
| `timeout` | Default query timeout (ms) | 5000 |
| `max_overflow` | Maximum overflow connections | ~30% of pool_size |

Example with all options:

```elixir
defmodule MyApp.ClickHouse do
  use Pillar,
    connection_strings: [
      "http://user:password@clickhouse-1:8123/database",
      "http://user:password@clickhouse-2:8123/database"
    ],
    name: __MODULE__,
    pool_size: 20,
    pool_timeout: 10_000,
    timeout: 30_000
end
```

## Using the Connection Pool

The Pillar-generated module provides functions that mirror the core Pillar API:

```elixir
# Execute a SELECT query
{:ok, users} = MyApp.ClickHouse.select(
  "SELECT * FROM users WHERE age > {min_age}",
  %{min_age: 21}
)

# Execute an INSERT query
{:ok, _} = MyApp.ClickHouse.insert(
  "INSERT INTO events (user_id, event) VALUES ({user_id}, {event})",
  %{user_id: 123, event: "login"}
)

# Insert data using a map
{:ok, _} = MyApp.ClickHouse.insert_to_table(
  "users",
  %{
    id: 456,
    name: "John Doe",
    email: "john@example.com"
  }
)
```

## Asynchronous Operations

One of the key benefits of using a connection pool is the ability to perform asynchronous operations:

```elixir
# Async insert
MyApp.ClickHouse.async_insert(
  "INSERT INTO logs (event, timestamp) VALUES ({event}, {timestamp})",
  %{event: "page_view", timestamp: DateTime.utc_now()}
)

# Async table insert
MyApp.ClickHouse.async_insert_to_table(
  "logs",
  %{
    event: "page_view",
    user_id: 123,
    timestamp: DateTime.utc_now()
  }
)
```

Asynchronous operations:
- Return immediately without waiting for a response
- Are ideal for logging, metrics, and other non-critical writes
- Improve application responsiveness
- Reduce backpressure

## High Availability and Load Balancing

When providing multiple connection strings, Pillar distributes queries across all available servers:

```elixir
defmodule MyApp.ClickHouse do
  use Pillar,
    connection_strings: [
      "http://user:password@clickhouse-1:8123/database",
      "http://user:password@clickhouse-2:8123/database",
      "http://user:password@clickhouse-3:8123/database"
    ],
    pool_size: 15
end
```

This setup provides:
- Load balancing across all servers
- Automatic failover if a server becomes unavailable
- Better query throughput

## Performance Considerations

- **Pool Size**: Should typically match your application's concurrency needs
- **Overflow**: Provides flexibility during traffic spikes
- **Timeouts**: Balance between responsiveness and resource utilization
- **Server Count**: More servers improve throughput but require more connections

For a high-traffic application, consider:

```elixir
defmodule MyApp.ClickHouse do
  use Pillar,
    connection_strings: [
      "http://user:password@clickhouse-1:8123/database",
      "http://user:password@clickhouse-2:8123/database",
      "http://user:password@clickhouse-3:8123/database"
    ],
    pool_size: 50,  # Larger pool
    pool_timeout: 5_000,  # Short timeout to fail fast
    timeout: 60_000  # Longer query timeout for complex queries
end
```

