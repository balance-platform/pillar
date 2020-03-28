defmodule Pillar.ResponseParser do
  @moduledoc false
  alias Pillar.HttpClient.Response
  alias Pillar.HttpClient.TransportError
  alias Pillar.TypeConvert.ToElixir

  def parse(%Response{status_code: 200, body: ""}) do
    {:ok, ""}
  end

  def parse(%Response{status_code: 200, body: body}) do
    case Jason.decode(body) do
      {:ok, map} ->
        meta = join_meta_to_map(map["meta"])
        {:ok, Enum.map(map["data"], fn row -> convert_row(meta, row) end)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def parse(%Response{status_code: _any, body: _body} = resp) do
    {:error, resp}
  end

  def parse(%TransportError{} = error) do
    {:error, error}
  end

  defp join_meta_to_map(meta_list) do
    meta_list
    |> Enum.reduce(%{}, fn %{"name" => name, "type" => type}, final_map ->
      Map.put(final_map, name, type)
    end)
  end

  defp convert_row(meta, row) do
    row
    |> Enum.map(fn {key, value} ->
      {key, ToElixir.convert(meta[key], value)}
    end)
    |> Map.new()
  end
end
