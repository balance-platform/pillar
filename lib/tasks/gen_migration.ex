defmodule Mix.Tasks.Pillar.Gen.Migration do
  @moduledoc """
  Migration Generator (very simple)

  ```
  $bash> mix pillar.gen.migration new_table
  => Migration generated priv/pillar_migrations/1592084569_new_table.exs
  ```
  """
  use Mix.Task
  alias Pillar.Migrations

  @impl Mix.Task
  def run([name]) do
    filepath = Migrations.generate(name)

    Mix.shell().info("Migration generated #{filepath}")
  end
end
