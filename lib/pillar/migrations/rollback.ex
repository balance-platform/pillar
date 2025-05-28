defmodule Pillar.Migrations.Rollback do
  @moduledoc false

  alias Pillar
  alias Pillar.Connection
  alias Pillar.Migrations.Base

  def rollback_n_migrations(%Connection{} = connection, path, rollback_count, options \\ %{}) do
    :ok = Base.create_migration_history_table(connection)

    files_and_modules = Base.compile_migration_files(path)

    migrations_for_rollback =
      connection
      |> list_of_success_migrations()
      |> Enum.sort()
      |> Enum.take(-Kernel.abs(rollback_count))

    migrations_for_rollback
    |> Enum.map(fn filename ->
      {_filename, module} =
        Enum.find(files_and_modules, fn {fname, _module} -> fname == filename end)

      :ok = do_rollback(connection, module, options)
      delete_migration_from_table(connection, filename)

      filename
    end)
  end

  def do_rollback(connection, module, options \\ %{}) do
    if function_exported?(module, :down, 0) do
      sql = module.down()

      multi = Base.multify_sql(sql)

      Enum.each(multi, fn sql ->
        {:ok, _result} = Pillar.query(connection, sql, %{}, options)
      end)

      :ok
    else
      :ok
    end
  end

  def list_of_success_migrations(connection) do
    sql = "SELECT migration FROM pillar_migrations"

    {:ok, data} = Pillar.select(connection, sql, %{})

    data
    |> Enum.map(fn %{"migration" => name} -> name end)
    |> Enum.sort()
  end

  def delete_migration_from_table(connection, migration) do
    sql = "ALTER TABLE pillar_migrations DELETE WHERE migration == {name}"

    {:ok, _result} = Pillar.query(connection, sql, %{name: migration})

    :ok
  end
end
