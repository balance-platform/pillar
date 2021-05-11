defmodule Pillar.Migrations.Base do
  @moduledoc false

  @default_path "priv/pillar_migrations"

  alias Pillar
  alias Pillar.Connection

  def compile_migration_files do
    base_path = Application.app_dir(:pillar, migrations_path())
    files = Enum.sort(File.ls!(base_path))

    files
    |> Enum.reject(fn filename -> filename == ".formatter.exs" end)
    |> Enum.map(fn filename ->
      module_name = file_name_to_module(filename)

      if Kernel.function_exported?(module_name, :up, 0) do
        {filename, module_name}
      else
        migration_path = Path.join(base_path, filename)
        [{module, _binary}] = Code.compile_file(migration_path)

        {filename, module}
      end
    end)
  end

  def migrations_path do
    Application.get_env(:pillar, :migrations_path, @default_path)
  end

  def create_migration_history_table(%Connection{} = connection) do
    sql = """
    CREATE TABLE IF NOT EXISTS pillar_migrations (
      migration String,
      inserted_at DateTime DEFAULT now()
    ) ENGINE = MergeTree()
    ORDER BY inserted_at
    """

    {:ok, _} = Pillar.query(connection, sql)

    :ok
  end

  defp file_name_to_module(filename) do
    name =
      filename
      |> String.replace(~r/\d+_(.*).exs/, "\\1")
      |> String.capitalize()

    "Elixir.Pillar.Migrations."
    |> Kernel.<>(name)
    |> String.to_atom()
  end
end
