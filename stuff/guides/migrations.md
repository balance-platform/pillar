# Migrations

Pillar provides a migrations system to help you manage your ClickHouse database schema changes in a version-controlled manner.

## Migration Basics

Migrations are Elixir modules that define schema changes. Each migration has:

- A timestamp prefix for ordering
- An `up` function that applies changes
- An optional `down` function for rollbacks

Pillar automatically tracks which migrations have been applied in a special `pillar_migrations` table.

## Generating Migrations

Use the built-in mix task to generate new migrations:

```bash
mix pillar.gen.migration create_users_table
```

This creates a file in `priv/pillar_migrations` with a timestamp prefix, for example:
`priv/pillar_migrations/20250528120000_create_users_table.exs`

The generated file looks like:

```elixir
defmodule Pillar.Migrations.CreateUsersTable do
  def up do
    # Your migration SQL goes here
  end

  def down do
    # Optional: code to roll back this migration
  end
end
```

## Writing Migrations

### Single Statement Migration

For simple migrations with a single SQL statement:

```elixir
defmodule Pillar.Migrations.CreateUsersTable do
  def up do
    """
    CREATE TABLE IF NOT EXISTS users (
      id UInt64,
      name String,
      email String,
      created_at DateTime
    ) ENGINE = MergeTree()
    ORDER BY id
    """
  end

  def down do
    "DROP TABLE IF EXISTS users"
  end
end
```

### Multi-Statement Migration

For more complex migrations requiring multiple SQL statements, return a list of strings:

```elixir
defmodule Pillar.Migrations.CreateAnalyticsTables do
  def up do
    [
      """
      CREATE TABLE IF NOT EXISTS page_views (
        user_id UInt64,
        page_url String,
        timestamp DateTime
      ) ENGINE = MergeTree()
      ORDER BY (timestamp, user_id)
      """,
      
      """
      CREATE TABLE IF NOT EXISTS user_sessions (
        session_id String,
        user_id UInt64,
        start_time DateTime,
        duration UInt32
      ) ENGINE = MergeTree()
      ORDER BY (start_time, session_id)
      """
    ]
  end

  def down do
    [
      "DROP TABLE IF EXISTS user_sessions",
      "DROP TABLE IF EXISTS page_views"
    ]
  end
end
```

### Dynamic Migrations

You can also generate migrations dynamically:

```elixir
defmodule Pillar.Migrations.CreateShardedTables do
  def up do
    Enum.map(0..4, fn shard ->
      """
      CREATE TABLE IF NOT EXISTS events_shard_#{shard} (
        id UUID,
        user_id UInt64,
        event_type String,
        created_at DateTime
      ) ENGINE = MergeTree()
      ORDER BY (created_at, id)
      """
    end)
  end

  def down do
    Enum.map(0..4, fn shard ->
      "DROP TABLE IF EXISTS events_shard_#{shard}"
    end)
  end
end
```

## Running Migrations

To run migrations, you'll need to create a mix task:

```elixir
defmodule Mix.Tasks.Clickhouse.Migrate do
  use Mix.Task
  
  @shortdoc "Runs ClickHouse migrations"
  
  def run(args) do
    # Start necessary applications
    [:postgrex, :ecto, :pillar]
    |> Enum.each(&Application.ensure_all_started/1)
    
    # Parse command-line arguments
    {opts, _, _} = OptionParser.parse(args, strict: [env: :string])
    env = Keyword.get(opts, :env, "dev")
    
    # Get connection URL from config
    url_key = String.to_atom("clickhouse_#{env}_url")
    url = Application.get_env(:my_app, url_key)
    
    # Create connection and run migrations
    conn = Pillar.Connection.new(url)
    
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
mix clickhouse.migrate
# Or with environment specification
mix clickhouse.migrate --env=prod
```

## Migration Tracking

Pillar automatically tracks applied migrations in a table called `pillar_migrations` in your ClickHouse database.

This table contains:
- The migration version (derived from the timestamp)
- The migration name
- When the migration was applied

You can query this table to see which migrations have been applied:

```sql
SELECT * FROM pillar_migrations ORDER BY version
```

## Rollbacks

To implement rollbacks, create another mix task:

```elixir
defmodule Mix.Tasks.Clickhouse.Rollback do
  use Mix.Task
  
  @shortdoc "Rolls back ClickHouse migrations"
  
  def run(args) do
    # Start necessary applications
    [:postgrex, :ecto, :pillar]
    |> Enum.each(&Application.ensure_all_started/1)
    
    # Parse command-line arguments
    {opts, _, _} = OptionParser.parse(args, strict: [env: :string, steps: :integer])
    env = Keyword.get(opts, :env, "dev")
    steps = Keyword.get(opts, :steps, 1)
    
    # Get connection URL from config
    url_key = String.to_atom("clickhouse_#{env}_url")
    url = Application.get_env(:my_app, url_key)
    
    # Create connection and run migrations
    conn = Pillar.Connection.new(url)
    
    case Pillar.Migrations.rollback(conn, steps) do
      :ok -> 
        Mix.shell().info("Rollback completed successfully")
      {:error, reason} -> 
        Mix.shell().error("Rollback failed: #{inspect(reason)}")
        exit({:shutdown, 1})
    end
  end
end
```

Then roll back the most recent migration with:

```bash
mix clickhouse.rollback
# Or roll back multiple migrations
mix clickhouse.rollback --steps=3
```

## Best Practices

1. **Keep migrations immutable** after they've been applied to production
2. **Test migrations** thoroughly in development and staging environments
3. **Include both `up` and `down` functions** for all migrations
4. **Use appropriate ClickHouse engines** based on your query patterns
5. **Comment complex migrations** to explain the purpose and approach
6. **Consider data preservation** when altering tables
7. **Avoid long-running migrations** in production

