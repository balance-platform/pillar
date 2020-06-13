defmodule Pillar.Migrations.GeneratorTest do
  use ExUnit.Case

  alias Pillar.Migrations.Generator

  test "#migration_template" do
    assert Generator.migration_template("Example") =~ ~r/defmodule Pillar.Migrations.Example/
  end

  test "#migration_filepath" do
    assert Generator.migration_filepath("Example") =~
             ~r/priv\/pillar_migrations\/\d{10}_example.exs/
  end
end
