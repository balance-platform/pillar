defmodule Pillar.HttpClientTest do
  alias Pillar.HttpClient
  alias Pillar.HttpClient.TransportError
  use ExUnit.Case

  alias Pillar.HttpClient.HttpcAdapter
  alias Pillar.HttpClient.TeslaMintAdapter

  for adapter <- [HttpcAdapter, TeslaMintAdapter] do
    @adapter adapter

    test "#{adapter} #post - econnrefused transport error" do
      assert %TransportError{
               reason: econnrefused_error
             } = HttpClient.post(@adapter, "http://localhost:1234")

      assert inspect(econnrefused_error) =~ "econnrefused"
    end

    test "#{adapter} #post - wrong scheme transport error" do
      assert %TransportError{reason: econnrefused_error} =
               HttpClient.post(@adapter, "https://localhost:1234")

      assert inspect(econnrefused_error) =~ "econnrefused"
    end

    test "#{adapter} #post - https scheme works" do
      assert %HttpClient.Response{} = HttpClient.post(@adapter, "https://www.google.com")
    end

    test "#{adapter} #post - binary data test" do
      assert %HttpClient.Response{} =
               HttpClient.post(@adapter, "https://www.google.com/favicon.ico")
    end
  end
end
