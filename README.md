# Pillar

Clickhouse elixir driver via HTTP connection

[![Coverage Status](https://coveralls.io/repos/github/sofakingworld/pillar/badge.svg?branch=master)](https://coveralls.io/github/sofakingworld/pillar?branch=master)
![build](https://github.com/CatTheMagician/pillar/workflows/Elixir%20CI/badge.svg)

<img src="https://sofakingworld.github.io/pillar.png" width="240">

## Usage

### Direct Usage with connection structure

```elixir

conn = Pillar.Connection.new("http://user:password@localhost:8123/database")

# params are passed in brackets {} in sql query, and map strtucture does fill query by values
sql = "SELECT count(*) FROM users WHERE lastname = {lastname}"

params = %{lastname: "Smith"}

{:ok, result} = Pillar.query(conn, sql, params)

result 
#=> [%{"count(*)" => 347}]

```

### Usage with workers supervisor tree

Recommended usage, because of limited connections and supervised workers

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
### Migrations

Migrations can be generated with mix task `mix pillar.gen.migration migration_name`

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

And launch this via command
```bash
mix migrate_clickhouse
```

### Async requests feature

```elixir
  connection = Pillar.Connection.new("http://user:password@host-master-1:8123/database")

  Pillar.async_insert(connection, "INSERT INTO events (user_id, event) SELECT {user_id}, {event}", %{
    user_id: user.id,
    event: "password_changed"
  }) # => :ok
```

## Installation

```elixir
def deps do
  [
    {:pillar, "~> 0.13.0"}
  ]
end
```

# Contribution

Feel free to make a pull request. All contributions are appreciated!
