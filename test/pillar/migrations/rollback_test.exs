defmodule Pillar.Migrations.RollbackTest do
  use ExUnit.Case
  alias Pillar.Migrations
  alias Pillar.Migrations.Rollback
  alias Pillar.Connection
  alias Pillar.HttpClient.Response

  @default_path "priv/pillar_migrations"

  setup do
    connection_url = Application.get_env(:pillar, :connection_url)
    connection = Connection.new(connection_url)

    Migrations.migrate(connection)

    {:ok, %{conn: connection, path: @default_path}}
  end

  test "#rollback_n_migrations", %{conn: conn, path: path} do
    result = Rollback.list_of_success_migrations(conn)
    assert length(result) >= 3

    # Nothing rollback
    assert Rollback.rollback_n_migrations(conn, path, 0) == []

    # List of rolled back migrations
    assert [_migration_file] = Rollback.rollback_n_migrations(conn, path, 1)

    # List of rolled back migrations, + wait until Clickhouse updates table
    :timer.sleep(3_000)

    assert [_migration_file1, _migration_file2, _migration_file3] =
             Rollback.rollback_n_migrations(conn, path, 3)

    # Migrations left, + wait until Clickhouse updates table
    :timer.sleep(1_000)
    result = Rollback.list_of_success_migrations(conn)
    assert Enum.empty?(result)

    # Checks, that tables are deleted
    Enum.each(["", 2, 3, 4], fn suffix ->
      assert {:error, %Response{body: body}} =
               Pillar.query(conn, "select count(*) from example_table#{suffix}")

      assert body =~ ~r/Code: 60. DB::Exception/
      assert body =~ ~r/example_table#{suffix}/
    end)
  end

  test "#list_of_success_migrations", %{conn: conn} do
    assert ["1592062613_example_migration.exs" | _tail] =
             Rollback.list_of_success_migrations(conn)
  end
end
