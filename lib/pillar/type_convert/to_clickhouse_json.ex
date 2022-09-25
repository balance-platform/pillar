defmodule Pillar.TypeConvert.ToClickhouseJson do
  @moduledoc false
  def convert(param) when is_list(param) do
    if !Enum.empty?(param) && Keyword.keyword?(param) do
      param
      |> Enum.map(fn {k, v} -> {to_string(k), convert(v)} end)
      |> Enum.into(%{})
    else
      Enum.map(param, &convert/1)
    end
  end

  def convert(param) when is_integer(param) do
    Integer.to_string(param)
  end

  def convert(param) when is_boolean(param) do
    case param do
      true -> 1
      false -> 0
    end
  end

  def convert(nil), do: nil

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
    param
  end

  def convert(param) do
    param
  end
end
