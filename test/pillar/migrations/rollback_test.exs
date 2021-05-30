defmodule Pillar.Migrations.RollbackTest do
  use ExUnit.Case
  alias Pillar.Migrations
  alias Pillar.Migrations.Rollback
  alias Pillar.Connection
  alias Pillar.HttpClient.Response

  alias Pillar.HttpClient.HttpcAdapter
  alias Pillar.HttpClient.TeslaMintAdapter

  for adapter <- [HttpcAdapter, TeslaMintAdapter] do
    @adapter adapter
    setup do
      connection_url = Application.get_env(:pillar, :connection_url)
      connection = Connection.new(connection_url, @adapter)

      Migrations.migrate(connection)

      {:ok, %{conn: connection}}
    end

    test "#{adapter} #rollback_n_migrations", %{conn: conn} do
      result = Rollback.list_of_success_migrations(conn)
      assert length(result) == 3

      # Nothing rollback
      assert Rollback.rollback_n_migrations(conn, 0) == []

      # List of rolled back migrations
      assert [_migration_file] = Rollback.rollback_n_migrations(conn, 1)

      # List of rolled back migrations, + wait until Clickhouse updates table
      :timer.sleep(3_000)
      assert [_migration_file1, _migration_file2] = Rollback.rollback_n_migrations(conn, 2)

      # Migrations left, + wait until Clickhouse updates table
      :timer.sleep(1_000)
      result = Rollback.list_of_success_migrations(conn)
      assert Enum.empty?(result)

      # Checks, that tables are deleted
      assert {:error, %Response{body: body}} =
               Pillar.query(conn, "select count(*) from example_table")

      assert {:error, %Response{body: body2}} =
               Pillar.query(conn, "select count(*) from example_table2")

      assert {:error, %Response{body: body3}} =
               Pillar.query(conn, "select count(*) from example_table3")

      assert body =~ ~r/example_table doesn\'t exist/
      assert body2 =~ ~r/example_table2 doesn\'t exist/
      assert body3 =~ ~r/example_table3 doesn\'t exist/
    end

    test "#{adapter} #list_of_success_migrations", %{conn: conn} do
      assert ["1592062613_example_migration.exs" | _tail] =
               Rollback.list_of_success_migrations(conn)
    end
  end
end
