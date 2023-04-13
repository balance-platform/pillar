defmodule Pillar.Ecto do
  use Ecto.Adapters.SQL,
    driver: Pillar.Ecto.Driver,
    migration_lock: "FOR UPDATE"

  def supports_ddl_transaction?(), do: false

  def lock_for_migrations(_, _, _), do: nil
end
