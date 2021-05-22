defmodule Pillar.MigrationsTest do
  use ExUnit.Case
  alias Pillar.Migrations.Default, as: Migrations

  test "#generate" do
    assert filename = Migrations.generate("test_migration")

    assert filename =~ ~r/priv\/pillar_migrations\/.*test_migration.exs/

    File.rm!(filename)
  end
end
