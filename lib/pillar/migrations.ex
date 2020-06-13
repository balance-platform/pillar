defmodule Pillar.Migrations do
  @moduledoc """
  Migration's mechanism

  For generation migration files use task `Mix.Tasks.Pillar.Gen.Migration`

  For launching migration define own mix task or release task with code below:
  ```
  conn = Pillar.Connection.new(connection_string)
  Pillar.Migrations.migrate(conn)
  ```
  """
  alias Pillar.Connection
  alias Pillar.Migrations.Generator
  alias Pillar.Migrations.Migrate

  def generate(name) do
    template = Generator.migration_template(name)

    with filepath <- Generator.migration_filepath(name),
         :ok <- File.mkdir_p!(Path.dirname(filepath)),
         :ok <- File.write!(filepath, template) do
      filepath
    end
  end

  def migrate(%Connection{} = conn) do
    Migrate.run_all_migrations(conn)
  end
end
