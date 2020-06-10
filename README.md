# Pillar

Clickhouse elixir driver via HTTP connection

[![Coverage Status](https://coveralls.io/repos/github/sofakingworld/pillar/badge.svg?branch=master)](https://coveralls.io/github/sofakingworld/pillar?branch=master)
![build](https://github.com/CatTheMagician/pillar/workflows/Elixir%20CI/badge.svg)

<img src="https://sofakingworld.github.io/pillar.png" width="640">

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

### Delayed inserts feature

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

  # delayed inserts
  ClickhouseMaster.async_insert("INSERT INTO events (user_id, event) SELECT {user_id}, {event}", %{
    user_id: user.id,
    event: "password_changed"
  }) # => :ok
```

## Installation

```elixir
def deps do
  [
    {:pillar, "~> 0.10.0"}
  ]
end
```