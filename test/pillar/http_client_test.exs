defmodule Pillar.HttpClientTest do
  alias Pillar.HttpClient
  alias Pillar.HttpClient.TransportError
  use ExUnit.Case

  test "#post - econnrefused transport error" do
    assert %TransportError{reason: {:failed_connect,
               [{:to_address, {'localhost', 1234}}, {:inet, [:inet], :econnrefused}]}} = HttpClient.post("http://localhost:1234")
  end
  test "#post - wrong scheme transport error" do
    assert %TransportError{reason: {:bad_scheme, 'localhost'}} = HttpClient.post("localhost:1234")
  end

  test "#post - https scheme works" do
    assert %HttpClient.Response{} = HttpClient.post("https://www.google.com")
  end
end