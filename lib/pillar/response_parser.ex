defmodule Pillar.ResponseParser do
  @moduledoc false
  alias Pillar.HttpClient.Response
  alias Pillar.HttpClient.TransportError
  alias Pillar.TypeConvert.ToElixir

  def parse(%Response{status_code: 200, body: ""}) do
    {:ok, ""}
  end

  def parse(%Response{status_code: 200, body: body}) do
    {atom, result} = Jason.decode(body)

    cond do
      atom == :ok && is_map(result) ->
        meta = join_meta_to_map(result["meta"])
        {:ok, Enum.map(result["data"], fn row -> convert_row(meta, row) end)}

      atom == :ok ->
        {:ok, result}

      %Jason.DecodeError{data: data} = result ->
        {:ok, data}

      true ->
        {:ok, result}
    end
  end

  def parse(%Response{status_code: _any, body: _body} = resp) do
    {:error, resp}
  end

  def parse(%TransportError{} = error) do
    {:error, error}
  end

  def parse(%RuntimeError{} = error) do
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
