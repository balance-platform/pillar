defmodule Pillar.Migrations.BaseTest do
  use ExUnit.Case
  alias Pillar.Migrations.Base

  test "#compile_migration_files" do
    assert [
             {"1592062613_example_migration.exs", Pillar.Migrations.Example_migration}
             | _tail
           ] = Base.compile_migration_files()
  end
end
