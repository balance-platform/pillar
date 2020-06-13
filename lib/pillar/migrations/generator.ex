defmodule Pillar.Migrations.Generator do
  @moduledoc """
  Migration generator, used at Mix.Tasks
  """

  @default_path "priv/pillar_migrations"

  def migration_template(name) do
    """
    defmodule Pillar.Migrations.#{String.capitalize(name)} do
      def up do
        "CREATE TABLE example (field FixedString(10)) ENGINE = Memory"
      end

      def down do
        "DROP TABLE example"
      end
    end
    """
  end

  def migration_filepath(name) do
    unix_timestamp = DateTime.to_unix(DateTime.utc_now())

    module_name = String.downcase(name)
    Path.join([@default_path, "#{unix_timestamp}_#{module_name}.exs"])
  end
end
