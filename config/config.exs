import Config

adapter =
  case System.get_env("PILLAR_HTTP_ADAPTER") do
    "HttpcAdapter" -> Pillar.HttpClient.HttpcAdapter
    "TeslaMintAdapter" -> Pillar.HttpClient.TeslaMintAdapter
    _other_cases -> nil
  end

config :pillar, Pillar.HttpClient, http_adapter: adapter

config :pillar,
  connection_url: System.get_env("CLICKHOUSE_URL") || "http://localhost:8123"
