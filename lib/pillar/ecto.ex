defmodule Pillar.Ecto do
  use Ecto.Adapters.SQL,
    driver: Pillar.Ecto.Driver,
    migration_lock: "FOR UPDATE"

  # TODO: Make user read only for now due to possible
  # SQL injection in as parameterized query is not being supported yet.
end
