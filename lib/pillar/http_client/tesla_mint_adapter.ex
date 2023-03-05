defmodule Pillar.HttpClient.TeslaMintAdapter do
  @moduledoc false
  alias Pillar.HttpClient.Response
  alias Pillar.HttpClient.TransportError

  def post(url, post_body \\ "", options \\ [timeout: 10_000]) do
    timeout = Keyword.get(options, :timeout, 10_000)

    middleware = [
      Tesla.Middleware.FollowRedirects,
      {Tesla.Middleware.Timeout, timeout: timeout}
    ]

    adapter = {Tesla.Adapter.Mint, timeout: timeout, transport_opts: [timeout: timeout]}

    result =
      middleware
      |> Tesla.client(adapter)
      |> Tesla.post(url, post_body, [])

    response_to_app_structure(result)
  end

  defp response_to_app_structure(response_tuple) do
    case response_tuple do
      {:ok, %Tesla.Env{status: status_code, headers: headers, body: body}} ->
        %Response{
          status_code: status_code,
          body: format_body(body),
          headers: downcase_headers_names(headers)
        }

      {:error, %Mint.TransportError{reason: reason}} ->
        %TransportError{reason: reason}

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

  defp format_body(nil), do: ""
  defp format_body(data) when is_binary(data), do: data
  defp format_body(data) when is_list(data), do: IO.iodata_to_binary(data)
end
