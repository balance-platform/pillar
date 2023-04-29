defmodule Pillar.HttpClient.HttpcAdapter do
  @moduledoc false
  alias Pillar.HttpClient.Response
  alias Pillar.HttpClient.TransportError

  def post(url, post_body \\ "", headers \\ [], options \\ [timeout: 10_000]) do
    headers =
      headers
      |> List.wrap()
      |> Enum.map(fn {k, v} -> {String.to_charlist(k), String.to_charlist(v)} end)

    result =
      :httpc.request(
        :post,
        {String.to_charlist(url), headers ++ [{'te', 'application/json'}], 'application/json',
         post_body},
        options,
        []
      )

    response_to_app_structure(result)
  end

  defp response_to_app_structure(response_tuple) do
    case response_tuple do
      {:ok, {{_http_ver, status_code, _a_status_desc}, headers, body}} ->
        %Response{
          status_code: status_code,
          body: format_body(body),
          headers: downcase_headers_names(headers)
        }

      {:error, reason} ->
        %TransportError{reason: reason}
    end
  end

  defp downcase_headers_names(headers) do
    Enum.map(headers, fn {charlist_key, value} ->
      string_key = to_string(charlist_key)
      {String.downcase(string_key), to_string(value)}
    end)
  end

  defp format_body(data) when is_binary(data), do: data
  defp format_body(data) when is_list(data), do: IO.iodata_to_binary(data)
end
