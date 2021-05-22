defmodule Pillar.Migrations do
  @moduledoc """
  Migration's mechanism

  For generation migration files use task `Mix.Tasks.Pillar.Gen.Migration`

  For launching migration define own mix task or release task with code below:
  ```
  conn = Pillar.Connection.new(connection_string)
  Pillar.Migrations.Default.migrate(conn)
  ```
  """

  defmacro __using__(args) when is_list(args) do
    quote do
      alias Pillar.Connection
      alias Pillar.Migrations.Generator
      alias Pillar.Migrations.Migrate
      alias Pillar.Migrations.Rollback

      @default_path_suffix "priv/pillar_migrations"
      @path_suffix Keyword.get(unquote(args), :path_suffix, @default_path_suffix)

      def generate(name) do
        template = Generator.migration_template(name)

        with filepath <- Generator.migration_filepath(name, migrations_path()),
             :ok <- File.mkdir_p!(Path.dirname(filepath)),
             :ok <- File.write!(filepath, template) do
          filepath
        end
      end

      def migrate(%Connection{} = conn) do
        Migrate.run_all_migrations(conn, migrations_path())
      end

      def rollback(%Connection{} = conn, count_of_migrations \\ 1) do
        Rollback.rollback_n_migrations(conn, migrations_path(), count_of_migrations)
      end

      def migrations_path do
        Path.join([get_path_prefix(), @path_suffix])
      end

      defp get_path_prefix do
        case Keyword.get(unquote(args), :path_prefix) do
          nil ->
            case Keyword.get(unquote(args), :otp_app) do
              nil ->
                ""

              otp_app when is_atom(otp_app) ->
                Application.app_dir(otp_app)
            end

          path_prefix when is_binary(path_prefix) ->
            path_prefix
        end
      end
    end
  end
end
