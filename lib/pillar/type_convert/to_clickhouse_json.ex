defmodule Pillar.TypeConvert.ToClickhouseJson do
  @moduledoc false
  @behaviour Pillar.TypeConvert.Base

  def convert(param) when is_list(param) do
    values = Enum.map(param, &convert/1)

    "[#{values}]"
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
  end

  def convert(%Date{} = date) do
    date
    |> Date.to_iso8601()
  end

  def convert(param) when is_map(param) do
    json = Jason.encode!(param)
    convert(json)
  end

  def convert(param) when is_binary(param) do
    case Jason.decode(param) do
      {:ok, value} ->
        if is_map(value) do
          single_quotes_escaped = String.replace(param, "'", "''")
          ~s('#{single_quotes_escaped}')
        else
          param
        end

      _any ->
        param
    end
  end

  def convert(param) do
    param
  end
end
