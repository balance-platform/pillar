defmodule Pillar.Migrations.Base do
  @moduledoc false

  alias Pillar
  alias Pillar.Connection

  def compile_migration_files(path) do
    path
    |> File.ls!()
    |> Enum.sort()
    |> Enum.reject(fn filename -> filename == ".formatter.exs" end)
    |> Enum.map(fn filename ->
      module_name = file_name_to_module(filename)

      if Kernel.function_exported?(module_name, :up, 0) do
        {filename, module_name}
      else
        migration_path = Path.join(path, filename)
        [{module, _binary}] = Code.compile_file(migration_path)
        {filename, module}
      end
    end)
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
      |> Macro.camelize()

    "Elixir.Pillar.Migrations."
    |> Kernel.<>(name)
    |> String.to_atom()
  end

  def multify_sql(sql) do
    case sql do
      sql when is_binary(sql) ->
        [sql]

      multi when is_list(multi) ->
        multi
    end
  end
end
