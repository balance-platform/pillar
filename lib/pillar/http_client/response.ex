defmodule Pillar.HttpClient.Response do
  @moduledoc """
  Wrapper for HTTP response
  """
  defstruct [:status_code, :body, :headers]
end
