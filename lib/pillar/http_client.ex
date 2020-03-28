defmodule Pillar.HttpClient do
  @moduledoc """
  Обвязка для http клиента, которая логирует запросы в рамках одного процесса
  """
  require Logger
  alias Pillar.HttpClient.Response
  alias Pillar.HttpClient.TransportError

  def post(url, post_body \\ "", headers \\ [], options \\ [timeout: 10_000]) do
    client = build_client(headers, options)

    client
    |> Tesla.post(url, post_body, options)
    |> tesla_response_to_app_response()
  end

  defp build_client(headers, options) do
    Tesla.client([
      {Tesla.Middleware.Headers, headers},
      {Tesla.Middleware.Timeout, options}
    ])
  end

  defp tesla_response_to_app_response(response_tuple) do
    case response_tuple do
      {:ok, %Tesla.Env{status: status, body: body, headers: headers}} ->
        %Response{status_code: status, body: body, headers: downcase_headers_names(headers)}

      {:error, reason} ->
        %TransportError{reason: reason}
    end
  end

  # Функция преобразования названий заголовков в нижний регистр, чтобы уменьшить зависимость от
  # особенностей используемых http клиентов
  defp downcase_headers_names(headers) do
    Enum.map(headers, fn {key, value} ->
      {String.downcase(key), value}
    end)
  end
end
