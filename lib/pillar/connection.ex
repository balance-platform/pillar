defmodule Pillar.Connection do
  @moduledoc false
  defstruct host: nil,
            port: nil,
            scheme: nil,
            password: nil,
            user: nil,
            database: nil

  def from_string(str) do
    uri = URI.parse(str)

    [user, password] =
      case uri.userinfo do
        nil -> [nil, nil]
        _str -> String.split(uri.userinfo, ":")
      end

    %__MODULE__{
      host: uri.host,
      port: uri.port,
      scheme: uri.scheme,
      database: Path.basename(uri.path || "default"),
      user: user,
      password: password
    }
  end

  def url_from_connection(%__MODULE__{} = connect_config) do
    params =
      reject_nils(%{
        password: connect_config.password,
        user: connect_config.user,
        database: connect_config.database
      })

    uri_struct = %URI{
      host: connect_config.host,
      scheme: connect_config.scheme,
      port: connect_config.port,
      query: URI.encode_query(params),
      path: "/"
    }

    URI.to_string(uri_struct)
  end

  defp reject_nils(map) do
    map
    |> Enum.reject(fn {_k, value} -> is_nil(value) end)
    |> Map.new()
  end
end
