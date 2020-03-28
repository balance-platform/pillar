# Pillar

Clickhouse elixir driver via HTTP connection

[![Coverage Status](https://coveralls.io/repos/github/sofakingworld/pillar/badge.svg?branch=master)](https://coveralls.io/github/sofakingworld/pillar?branch=master)
![build](https://github.com/sofakingworld/pillar/workflows/Elixir%20CI/badge.svg)

<img src="https://sofakingworld.github.io/pillar.png" width="640">

## Usage

```elixir

conn = Pillar.Connection.new("http://user:password@localhost:8123/database)

# params are passed in brackets {} in sql query, and map strtucture does fill query by values
sql = "SELECT count(*) FROM users WHERE lastname = {lastname}"

params = %{lastname: "Smith"}

{:ok, result} = Pillar.query(conn, sql, params)

result 
#=> %{"count(*)" => 347}

```

## Installation

```elixir
def deps do
  [
    {:pillar, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/pillar](https://hexdocs.pm/pillar).

