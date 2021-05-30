defmodule Pillar.Migrations.MigrateTest do
  use ExUnit.Case
  alias Pillar.Migrations.Migrate
  alias Pillar.Connection

  alias Pillar.HttpClient.HttpcAdapter
  alias Pillar.HttpClient.TeslaMintAdapter

  for adapter <- [HttpcAdapter, TeslaMintAdapter] do
    @adapter adapter
    setup do
      connection_url = Application.get_env(:pillar, :connection_url)
      connection = Connection.new(connection_url, @adapter)

      {:ok, %{conn: connection}}
    end

    test "#{adapter} #run_all_migrations", %{conn: conn} do
      assert [{"1592062613_example_migration.exs", result} | _tail] =
               Migrate.run_all_migrations(conn)

      assert result in [:already_up, :migrated]
    end
  end
end
