defmodule Pillar.HttpClient.TransportError do
  @moduledoc """
  Wrap for HTTP transport errors, such as timeout and etc
  """

  defstruct [:reason]

  @type t :: %{
          reason: any
        }
end
