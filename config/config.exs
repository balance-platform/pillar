import Config

config :pillar,
  connection_url: System.get_env("CLICKHOUSE_URL") || "http://localhost:8123"

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase
