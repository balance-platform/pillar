defmodule Pillar.HttpClientTest do
  alias Pillar.HttpClient
  alias Pillar.HttpClient.TransportError
  use ExUnit.Case

  describe "#adapter" do
    test "adapter is set by config" do
      assert HttpClient.adapter() in [
               Pillar.HttpClient.HttpcAdapter,
               Pillar.HttpClient.TeslaMintAdapter
             ]
    end

    test "System.get_env(PILLAR_HTTP_ADAPTER) sets adapter" do
      if value = System.get_env("PILLAR_HTTP_ADAPTER") != nil do
        if value == "HttpcAdapter" do
          assert HttpClient.adapter() == Pillar.HttpClient.HttpcAdapter
        end

        if value == "TeslaMintAdapter" do
          assert HttpClient.adapter() == Pillar.HttpClient.TeslaMintAdapter
        end
      end
    end
  end

  test "#post - econnrefused transport error" do
    assert %TransportError{
             reason: reason
           } = HttpClient.post("http://localhost:1234")

    assert inspect(reason) =~ "econnrefused"
  end

  test "#post - wrong scheme transport error" do
    assert %TransportError{reason: reason} = HttpClient.post("https://localhost:1234")
    assert inspect(reason) =~ "econnrefused"
  end

  test "#post - https scheme works" do
    assert %HttpClient.Response{} = HttpClient.post("https://www.google.com")
  end

  test "#post - binary data test" do
    assert %HttpClient.Response{} = HttpClient.post("https://www.google.com/favicon.ico")
  end
end
