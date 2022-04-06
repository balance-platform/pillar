defmodule Pillar.TypeConvert.ToClickhouse do
  @moduledoc false
  def convert(param) when is_list(param) do
    if Keyword.keyword?(param) && !Enum.empty?(param) do
      values =
        param
        |> Enum.map(fn {k, v} -> "'#{to_string(k)}':#{convert(v)}" end)
        |> Enum.join(",")

      "{#{values}}"
    else
      values = Enum.map_join(param, ",", &convert/1)

      "[#{values}]"
    end
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

  def convert({a, b, c, d} = ip)
      when is_integer(a) and is_integer(b) and is_integer(c) and is_integer(d) and
             a >= 0 and
             a <= 255 and b >= 0 and b <= 255 and c >= 0 and
             c <= 255 and d >= 0 and d <= 255 do
    ip
    |> :inet.ntoa()
    |> to_string
    |> convert
  end

  def convert({a, b, c, d, e, f, g, h} = ip)
      when is_integer(a) and is_integer(b) and is_integer(c) and is_integer(d) and is_integer(e) and
             is_integer(f) and is_integer(g) and is_integer(h) and a >= 0 and
             a <= 65535 and
             b >= 0 and b <= 65535 and
             c >= 0 and c <= 65535 and
             d >= 0 and d <= 65535 and
             e >= 0 and e <= 65535 and
             f >= 0 and f <= 65535 and
             g >= 0 and g <= 65535 and
             h >= 0 and h <= 65535 do
    ip
    |> :inet.ntoa()
    |> to_string
    |> convert
  end

  def convert(param) do
    single_quotes_escaped = String.replace(param, "'", "''")

    ~s('#{single_quotes_escaped}')
  end
end
