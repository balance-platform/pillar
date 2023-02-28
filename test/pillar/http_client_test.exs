defmodule Pillar.HttpClientTest do
  alias Pillar.HttpClient
  alias Pillar.HttpClient.TransportError
  use ExUnit.Case

  test "#post - econnrefused transport error" do
    assert %TransportError{
             reason: :econnrefused
           } = HttpClient.post("http://localhost:1234", "", pool: PillarFinchPool)
  end

  test "#post - wrong scheme transport error" do
    assert %TransportError{reason: :econnrefused} =
             HttpClient.post("https://localhost:1234", "", pool: PillarFinchPool)
  end

  test "#post - https scheme works" do
    assert %HttpClient.Response{} =
             HttpClient.post("https://www.google.com", "", pool: PillarFinchPool)
  end

  test "#post - binary data test" do
    assert %HttpClient.Response{} =
             HttpClient.post("https://www.google.com/favicon.ico", "", pool: PillarFinchPool)
  end
end
