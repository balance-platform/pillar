defmodule Pillar.Migrations.GeneratorTest do
  use ExUnit.Case

  alias Pillar.Migrations.Generator

  @default_path "priv/pillar_migrations"

  test "#migration_template" do
    assert Generator.migration_template("Example") =~ ~r/defmodule Pillar.Migrations.Example/
  end

  test "#migration_filepath" do
    assert Generator.migration_filepath("Example", @default_path) =~
             ~r/priv\/pillar_migrations\/\d{10}_example.exs/
  end
end
