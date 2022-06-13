defmodule Pillar.HttpClient do
  @moduledoc false
  @default_http_adapter Pillar.HttpClient.TeslaMintAdapter

  @spec post(String.t(), String.t(), Keyword.t()) ::
          Pillar.HttpClient.Response.t()
          | Pillar.HttpClient.TransportError.t()
          | RuntimeError.t()
  def post(url, post_body \\ "", options \\ [timeout: 10_000]) do
    http_adapter = adapter()

    if Code.ensure_loaded(http_adapter) && function_exported?(http_adapter, :post, 3) do
      http_adapter.post(url, post_body, options)
    else
      %RuntimeError{message: "#{inspect(http_adapter)} is not loaded or unknown"}
    end
  end

  def adapter do
    module =
      Application.get_all_env(:pillar)
      |> Access.get(__MODULE__, [])
      |> Access.get(:http_adapter)

    module || @default_http_adapter
  end
end
