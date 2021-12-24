# Pillar

[![github.com](https://github.com/balance-platform/pillar/workflows/build/badge.svg?branch=master)](https://github.com/balance-platform/pillar/actions)
[![hex.pm](https://img.shields.io/badge/docs-hexpm-blue.svg)](https://hexdocs.pm/pillar)
[![hex.pm](https://img.shields.io/hexpm/v/pillar.svg)](https://hex.pm/packages/pillar)
[![hex.pm](https://img.shields.io/hexpm/dt/pillar.svg)](https://hex.pm/packages/pillar)
[![hex.pm](https://img.shields.io/hexpm/l/pillar.svg)](https://hex.pm/packages/pillar)
[![github.com](https://img.shields.io/github/last-commit/balance-platform/pillar.svg)](https://github.com/balance-platform/pillar/commits/master)

Elixir client for [ClickHouse](https://clickhouse.tech/), a fast open-source
Online Analytical Processing (OLAP) database management system.

# Features

  - [Direct Usage with connection structure](#direct-usage-with-connection-structure)
  - [Pool of workers](#pool-of-workers)
  - [Async insert](#async-insert)
  - [Buffer for periodical bulk inserts](#buffer-for-periodical-bulk-inserts)
  - [Migrations](#migrations)

## Usage

### Direct Usage with connection structure

```elixir
conn = Pillar.Connection.new("http://user:password@localhost:8123/database")

# Params are passed in brackets {} in SQL query, and map strtucture does fill
# query by values.
sql = "SELECT count(*) FROM users WHERE lastname = {lastname}"

params = %{lastname: "Smith"}

{:ok, result} = Pillar.query(conn, sql, params)

result
#=> [%{"count(*)" => 347}]

```

### Pool of workers

Recommended usage, because of limited connections and supervised workers.

```elixir
defmodule ClickhouseMaster do
  use Pillar,
    connection_strings: [
      "http://user:password@host-master-1:8123/database",
      "http://user:password@host-master-2:8123/database"
    ],
    name: __MODULE__,
    pool_size: 15
end

ClickhouseMaster.start_link()

{:ok, result} = ClickhouseMaster.select(sql, %{param: value})
```

### Async insert

```elixir
connection = Pillar.Connection.new("http://user:password@host-master-1:8123/database")

Pillar.async_insert(connection, "INSERT INTO events (user_id, event) SELECT {user_id}, {event}", %{
  user_id: user.id,
  event: "password_changed"
}) # => :ok
```

### Buffer for periodical bulk inserts

For this feature required [Pool of workers](#pool-of-workers).

```elixir
defmodule BulkToLogs do
  use Pillar.BulkInsertBuffer,
    pool: ClickhouseMaster,
    table_name: "logs",
    # interval_between_inserts_in_seconds, by default -> 5
    interval_between_inserts_in_seconds: 5,
    # on_errors is optional
    on_errors: &__MODULE__.dump_to_file/2

  @doc """
  dump to file function store failed inserts into file 
  """
  def dump_to_file(_result, records) do
    File.write("bad_inserts/#{DateTime.utc_now()}", inspect(records))
  end

  @doc """
  retry insert is dangerous (but it is possible and listed as proof of concept)

  this function may be used in `on_errors` option
  """
  def retry_insert(_result, records) do
    __MODULE__.insert(records)
  end
end
```

```elixir
:ok = BulkToLogs.insert(%{value: "online", count: 133, datetime: DateTime.utc_now()})
:ok = BulkToLogs.insert(%{value: "online", count: 134, datetime: DateTime.utc_now()})
:ok = BulkToLogs.insert(%{value: "online", count: 132, datetime: DateTime.utc_now()})
....

# All this records will be inserted with 5 second interval.
```

*on_errors* parameter allows you to catch any error of bulk insert (for example: one of batch is bad or clickhouse was not available )


### Migrations

Migrations can be generated with mix task `mix pillar.gen.migration
migration_name`.

```bash
mix pillar.gen.migration events_table
```

But for launching them we have to write own task, like this:

```elixir
defmodule Mix.Tasks.MigrateClickhouse do
  use Mix.Task
  def run(_args) do
    connection_string = Application.get_env(:my_project, :clickhouse_url)
    conn = Pillar.Connection.new(connection_string)
    Pillar.Migrations.migrate(conn)
  end
end
```

And launch this via command.

```bash
mix migrate_clickhouse
```

### Timezones

In order to be able to use Timezones add timezones database to your project and configure your app:

```elixir
config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase
```

Details here https://hexdocs.pm/elixir/1.12/DateTime.html#module-time-zone-database

# Contribution

Feel free to make a pull request. All contributions are appreciated!
