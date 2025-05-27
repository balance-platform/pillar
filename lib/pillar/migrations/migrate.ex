defmodule Pillar.Migrations.Migrate do
  @moduledoc false

  alias Pillar
  alias Pillar.Connection
  alias Pillar.Migrations.Base

  def run_all_migrations(%Connection{} = connection, path, options \\ %{}) do
    :ok = Base.create_migration_history_table(connection)

    files_and_modules = Base.compile_migration_files(path)

    Enum.map(files_and_modules, fn {filename, module} ->
      result = migrate_if_was_not_migrated(connection, filename, module.up(), options)
      {filename, result}
    end)
  end

  def migrate_if_was_not_migrated(connection, migration_name, sql, options) do
    {:ok, [%{"qty" => count}]} =
      Pillar.select(
        connection,
        "SELECT COUNT(*) as qty FROM pillar_migrations WHERE migration = {name}",
        %{
          "name" => migration_name
        }
      )

    case count do
      0 ->
        multi = Base.multify_sql(sql)

        Enum.each(multi, fn sql ->
          {:ok, _} = Pillar.query(connection, sql, %{})
        end)

        {:ok, _} =
          Pillar.insert(
            connection,
            "INSERT INTO pillar_migrations (migration) SELECT {name}",
            %{
              name: migration_name
            },
            options
          )

        :migrated

      _ ->
        :already_up
    end
  end
end
