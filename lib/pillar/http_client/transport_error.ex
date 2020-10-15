defmodule Pillar.HttpClient.TransportError do
  @moduledoc """
  Wrapper for HTTP transport errors, such as timeout and etc
  """

  defstruct [:reason]

  @type t :: %{
          reason: any
        }
end
