defmodule Pillar.Migrations.Example_migration2 do
  def up do
    "CREATE TABLE IF NOT EXISTS example_table2 (field FixedString(10)) ENGINE = Memory"
  end

  def down do
    "DROP TABLE example_table2"
  end
end
