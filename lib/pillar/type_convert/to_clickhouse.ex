defmodule Pillar.TypeConvert.ToClickhouse do
  @moduledoc false
  @behaviour Pillar.TypeConvert.Base

  def convert(param) when is_list(param) do
    values = Enum.map_join(param, ",", &convert/1)

    "[#{values}]"
  end

  def convert(nil) do
    "NULL"
  end

  def convert(param) when is_integer(param) do
    Integer.to_string(param)
  end

  def convert(param) when is_boolean(param) do
    case param do
      true -> "1"
      false -> "0"
    end
  end

  def convert(param) when is_atom(param) do
    Atom.to_string(param)
  end

  def convert(param) when is_float(param) do
    Float.to_string(param)
  end

  def convert(%DateTime{} = datetime) do
    datetime
    |> DateTime.truncate(:second)
    |> DateTime.to_iso8601()
    |> String.replace("Z", "")
    |> convert()
  end

  def convert(%Date{} = date) do
    date
    |> Date.to_iso8601()
    |> convert()
  end

  def convert(param) when is_map(param) do
    json = Jason.encode!(param)
    convert(json)
  end

  def convert(param) do
    single_quotes_escaped = String.replace(param, "'", "''")

    ~s('#{single_quotes_escaped}')
  end
end
