defmodule Pillar.Migrations.MigrateTest do
  use ExUnit.Case
  alias Pillar.Migrations.Migrate
  alias Pillar.Connection

  @default_path "priv/pillar_migrations"

  setup do
    connection_url = Application.get_env(:pillar, :connection_url)
    connection = Connection.new(connection_url)

    {:ok, %{conn: connection, path: @default_path}}
  end

  test "#run_all_migrations", %{conn: conn, path: path} do
    assert [{"1592062613_example_migration.exs", result} | _tail] =
             Migrate.run_all_migrations(conn, path)

    assert result in [:already_up, :migrated]
  end
end
