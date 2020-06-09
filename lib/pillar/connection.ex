defmodule Pillar.Connection do
  @moduledoc """
  Structure with connection config, such as host, port, user, password and other
  """

  @type t() :: %{
          host: String.t(),
          port: integer,
          scheme: String.t(),
          password: String.t(),
          user: String.t(),
          database: String.t()
        }
  defstruct host: nil,
            port: nil,
            scheme: nil,
            password: nil,
            user: nil,
            database: nil

  @doc """
  Generates Connection from typical connection string:

  ```
  %Pillar.Connection{} = Pillar.Connection.new("https://user:password@localhost:8123/some_database")

  # in this case "default" database is used
  %Pillar.Connection{} = Pillar.Connection.new("https://localhost:8123")
  ```
  """
  @spec new(String.t()) :: Pillar.Connection.t()
  def new(str) do
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
