defmodule Pillar.HttpClient do
  @moduledoc false

  defmodule Adapter do
    @moduledoc "A behaviour to be implemented by adapters"

    @doc "A callback to be implemented by adapters"
    @callback post(url :: String.t(), post_body :: String.t(), options :: keyword()) ::
                Pillar.HttpClient.Response.t()
                | Pillar.HttpClient.TransportError.t()
                | %{__struct__: RuntimeError, message: String.t()}
  end

  @default_http_adapter Application.compile_env(
                          :pillar,
                          :http_adapter,
                          Pillar.HttpClient.TeslaMintAdapter
                        )

  @behaviour Adapter

  @impl Adapter
  def post(url, post_body \\ "", options \\ [timeout: 10_000]) do
    http_adapter = adapter()

    if Code.ensure_loaded(http_adapter) && function_exported?(http_adapter, :post, 3) do
      http_adapter.post(url, post_body, options)
    else
      %RuntimeError{message: "#{inspect(http_adapter)} is not loaded or unknown"}
    end
  end

  def adapter do
    :pillar
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:http_adapter)
    |> Kernel.||(@default_http_adapter)
  end
end
