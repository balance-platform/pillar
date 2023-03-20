defmodule Pillar.Ecto do
  use Ecto.Adapters.SQL,
    driver: Pillar.Ecto.Driver,
    migration_lock: "FOR UPDATE"
end
