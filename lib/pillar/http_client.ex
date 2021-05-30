defmodule Pillar.HttpClient do
  @moduledoc false
  alias Pillar.HttpClient
  alias Pillar.HttpClient.Response
  alias Pillar.HttpClient.TransportError

  def post(adapter, url, post_body \\ "", options \\ [timeout: 10_000])
      when adapter in [HttpClient.HttpcAdapter, HttpClient.TeslaMintAdapter] do
    adapter.post(url, post_body, options)
  end
end
