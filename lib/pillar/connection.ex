defmodule Pillar.Connection do
  @moduledoc """
  Structure with connection config, such as host, port, user, password and other
  """

  @boolean_to_clickhouse %{
    true => 1,
    false => 0
  }

  @type t() :: %{
          host: String.t(),
          port: integer,
          scheme: String.t(),
          password: String.t(),
          user: String.t(),
          database: String.t(),
          pool: Finch.name(),
          max_query_size: integer() | nil,
          allow_suspicious_low_cardinality_types: boolean() | nil
        }
  defstruct host: nil,
            port: nil,
            scheme: nil,
            password: nil,
            user: nil,
            database: nil,
            pool: Pillar.Application.default_finch_instance(),
            max_query_size: nil,
            allow_suspicious_low_cardinality_types: nil

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

    params = URI.decode_query(uri.query || "")

    %__MODULE__{
      host: uri.host,
      port: uri.port,
      scheme: uri.scheme,
      database: Path.basename(uri.path || "default"),
      user: user,
      password: password,
      max_query_size: nil_or_string_to_int(params["max_query_size"])
    }
  end

  def url_from_connection(%__MODULE__{} = connect_config, options \\ %{}) do
    params =
      reject_nils(%{
        password: connect_config.password,
        user: connect_config.user,
        database: connect_config.database,
        max_query_size: connect_config.max_query_size,
        allow_suspicious_low_cardinality_types:
          @boolean_to_clickhouse[connect_config.allow_suspicious_low_cardinality_types]
      })

    params =
      case Map.fetch(options, :db_side_batch_insertions) do
        {:ok, true} -> Map.put(params, "async_insert", 1)
        _ -> params
      end

    uri_struct = %URI{
      host: connect_config.host,
      scheme: connect_config.scheme,
      port: connect_config.port,
      query: URI.encode_query(params),
      path: "/"
    }

    URI.to_string(uri_struct)
  end

  defp nil_or_string_to_int(value) do
    if is_nil(value) do
      nil
    else
      String.to_integer(value)
    end
  end

  defp reject_nils(map) do
    map
    |> Enum.reject(fn {_k, value} -> is_nil(value) end)
    |> Map.new()
  end
end
