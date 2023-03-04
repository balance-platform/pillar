defmodule Pillar.Migrations.CreateMultipleTables do
  def up do
    (0..number_of_shards()) |> Enum.map(fn i ->
      "CREATE TABLE IF NOT EXISTS shard_#{i} (field FixedString(10)) ENGINE = Memory"
    end)
  end

  def number_of_shards do
    (System.get_env("SHARDS_COUNT") || "10") |> String.to_integer()
  end
end
