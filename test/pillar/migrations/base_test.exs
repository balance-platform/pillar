defmodule Pillar.Migrations.BaseTest do
  use ExUnit.Case
  alias Pillar.Migrations.Base

  @default_path "priv/pillar_migrations"

  test "#compile_migration_files" do
    assert [
             {"1592062613_example_migration.exs", Pillar.Migrations.ExampleMigration}
             | _tail
           ] = Base.compile_migration_files(@default_path)
  end
end
