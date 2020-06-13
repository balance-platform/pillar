defmodule Pillar.Migrations.ExampleMigration do
  def up do
    "CREATE TABLE IF NOT EXISTS example_table (field FixedString(10)) ENGINE = Memory"
  end

  def down do
    "DROP TABLE example_table"
  end
end
