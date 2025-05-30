defmodule Pillar.Migrations.ExampleMigration3 do
  def up do
    [
      "CREATE TABLE IF NOT EXISTS example_table3 (field FixedString(10)) ENGINE = Memory",
      "CREATE TABLE IF NOT EXISTS example_table4 (field FixedString(10)) ENGINE = Memory"
    ]
  end

  def down do
    ["DROP TABLE IF EXISTS example_table3", "DROP TABLE IF EXISTS example_table4"]
  end
end
