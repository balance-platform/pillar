# Getting Started with Pillar

This guide will help you get up and running with Pillar, the Elixir client for ClickHouse.

## Installation

Add `pillar` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:pillar, "~> 0.40.0"}
  ]
end
```

Then run:

```bash
mix deps.get
```

## Basic Configuration

### Direct Connection

The simplest way to use Pillar is with a direct connection:

```elixir
# Create a connection to your ClickHouse server
conn = Pillar.Connection.new("http://user:password@localhost:8123/database")
```

The connection URL follows this format:
```
http://[username:password@]host[:port]/database
```

Where:
- `username` and `password` are your ClickHouse credentials (default: default/empty)
- `host` is the ClickHouse server hostname or IP
- `port` is the HTTP port (default: 8123)
- `database` is the database name

### Connection Options

You can provide additional options when creating a connection:

```elixir
conn = Pillar.Connection.new(
  "http://user:password@localhost:8123/database",
  %{
    timeout: 30_000,  # Connection timeout in milliseconds
    max_execution_time: 60,  # Maximum query execution time in seconds
    database: "analytics"  # Override database in URL
  }
)
```

## Basic Operations

### Running Queries

```elixir
# Simple query
{:ok, result} = Pillar.query(conn, "SELECT 1")

# Parameterized query
{:ok, users} = Pillar.select(
  conn,
  "SELECT * FROM users WHERE age > {min_age} LIMIT {limit}",
  %{min_age: 21, limit: 100}
)
```

### Inserting Data

```elixir
# Insert with parameters
{:ok, _} = Pillar.insert(
  conn,
  "INSERT INTO events (user_id, event_type, created_at) VALUES ({user_id}, {event_type}, {created_at})",
  %{user_id: 123, event_type: "login", created_at: DateTime.utc_now()}
)

# Insert a record using a map
{:ok, _} = Pillar.insert_to_table(
  conn,
  "users",
  %{
    id: 456,
    name: "John Doe",
    email: "john@example.com",
    created_at: DateTime.utc_now()
  }
)

# Insert multiple records
{:ok, _} = Pillar.insert_to_table(
  conn,
  "users",
  [
    %{id: 1, name: "Alice", email: "alice@example.com"},
    %{id: 2, name: "Bob", email: "bob@example.com"},
    %{id: 3, name: "Charlie", email: "charlie@example.com"}
  ]
)
```

## Understanding Responses

Most Pillar functions return one of these response patterns:

```elixir
{:ok, result} # Success with result data
{:error, reason} # Error with reason
```

For example:

```elixir
case Pillar.select(conn, "SELECT * FROM users LIMIT 10") do
  {:ok, users} ->
    # Do something with the users list
    Enum.each(users, &IO.inspect/1)
    
  {:error, error} ->
    # Handle the error
    Logger.error("Query failed: #{inspect(error)}")
end
```

## Next Steps

Now that you have a basic understanding of how to use Pillar, you might want to explore:

- [Connection Pool](connection_pool.html) for managing multiple connections
- [Migrations](migrations.html) for managing your ClickHouse schema
- [Bulk Insert Strategies](bulk_inserts.html) for efficiently loading data

