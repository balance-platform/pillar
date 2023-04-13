defmodule Pillar.Ecto.QueryParam do
  defstruct [:field, :type, :name, :value]
end

defimpl String.Chars, for: Pillar.Ecto.QueryPara do
  def to_string(%{name: name}), do: name
end
