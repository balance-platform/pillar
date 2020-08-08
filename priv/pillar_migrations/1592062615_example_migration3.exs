defmodule Pillar.Migrations.Example_migration3 do
  def up do
    "CREATE TABLE IF NOT EXISTS example_table3 (field FixedString(10)) ENGINE = Memory"
  end

  def down do
    "DROP TABLE example_table3"
  end
end
