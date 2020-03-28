defmodule Pillar.HttpClient do
  @moduledoc false
  require Logger
  alias Pillar.HttpClient.Response
  alias Pillar.HttpClient.TransportError

  def post(url, post_body \\ "", options \\ [timeout: 10_000]) do
    result = :httpc.request(:post, {String.to_charlist(url), [], 'application/json', String.to_charlist(post_body)},  [], [])
    response_to_app_structure(result)
  end

  defp response_to_app_structure(response_tuple) do
    case response_tuple do
      {:ok, {{_http_ver, status_code, _a_status_desc}, headers, charlist_body}} ->
        %Response{status_code: status_code, body: to_string(charlist_body), headers: downcase_headers_names(headers)}

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
end
