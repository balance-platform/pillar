defmodule Pillar.Ecto.QueryParam do
  defstruct [:field, :type, :name, :value, :clickhouse_type]
end

defimpl String.Chars, for: Pillar.Ecto.QueryParam do
  def to_string(%{name: name, clickhouse_type: clickhouse_type}),
    do: "{#{name}:#{clickhouse_type}}"
end
