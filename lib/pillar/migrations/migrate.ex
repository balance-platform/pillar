defmodule Pillar.Migrations.Migrate do
  @moduledoc false

  alias Pillar
  alias Pillar.Connection

  @default_path "priv/pillar_migrations"

  def run_all_migrations(%Connection{} = connection) do
    {:ok, _} = Pillar.query(connection, create_migration_history_table_sql())

    files_and_modules = compile_migration_files()

    Enum.map(files_and_modules, fn {filename, module} ->
      result = migrate_if_was_not_migrated(connection, filename, module.up)
      {filename, result}
    end)
  end

  def compile_migration_files do
    files = Enum.sort(File.ls!(@default_path))

    files
    |> Enum.reject(fn filename -> filename == ".formatter.exs" end)
    |> Enum.map(fn filename ->
      migration_path = Path.join(@default_path, filename)
      [{module, _binary}] = Code.compile_file(migration_path)

      {filename, module}
    end)
  end

  def migrate_if_was_not_migrated(connection, migration_name, sql) do
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
        {:ok, _} = Pillar.query(connection, sql)

        {:ok, _} =
          Pillar.insert(connection, "INSERT INTO pillar_migrations (migration) SELECT {name}", %{
            name: migration_name
          })

        :migrated

      _ ->
        :already_up
    end
  end

  def create_migration_history_table_sql do
    """
    CREATE TABLE IF NOT EXISTS pillar_migrations (
      migration String,
      inserted_at DateTime DEFAULT now()
    ) ENGINE = MergeTree()
    ORDER BY inserted_at
    """
  end
end
