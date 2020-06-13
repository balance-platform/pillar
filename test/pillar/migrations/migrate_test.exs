defmodule Pillar.Migrations.MigrateTest do
  use ExUnit.Case
  alias Pillar.Migrations.Migrate
  alias Pillar.Connection

  setup do
    connection_url = Application.get_env(:pillar, :connection_url)
    connection = Connection.new(connection_url)

    {:ok, %{conn: connection}}
  end

  test "#compile_migration_files" do
    assert Migrate.compile_migration_files() == [
             {"1592062613_example_migration.exs", Pillar.Migrations.ExampleMigration}
           ]
  end

  test "#run_all_migrations", %{conn: conn} do
    assert [{"1592062613_example_migration.exs", result}] = Migrate.run_all_migrations(conn)

    assert result in [:already_up, :migrated]
  end
end
