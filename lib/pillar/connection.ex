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
          max_query_size: integer() | nil,
          allow_suspicious_low_cardinality_types: boolean() | nil
        }
  defstruct host: nil,
            port: nil,
            scheme: nil,
            password: nil,
            user: nil,
            database: nil,
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

    info = uri.userinfo

    [user, password] =
      cond do
        is_nil(info) -> [nil, nil]
        not String.contains?(info, ":") -> [info, nil]
        :else -> String.split(info, ":")
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

  def headers_from_connection(%__MODULE__{} = connect_config) do
    [
      {"X-ClickHouse-User", connect_config.user},
      {"X-ClickHouse-Key", connect_config.password}
    ]
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
  end

  def url_from_connection(%__MODULE__{} = connect_config, options \\ %{}) do
    params =
      reject_nils(%{
        database: connect_config.database,
        max_query_size: connect_config.max_query_size,
        allow_suspicious_low_cardinality_types:
          @boolean_to_clickhouse[connect_config.allow_suspicious_low_cardinality_types]
      })

    params = parse_options(params, options)

    uri_struct = %URI{
      host: connect_config.host,
      scheme: connect_config.scheme,
      port: connect_config.port,
      query: URI.encode_query(params),
      path: "/"
    }

    URI.to_string(uri_struct)
  end

  defp parse_options(params, %{db_side_batch_insertions: true} = options) do
    Map.put(params, "async_insert", 1)
    |> parse_options(Map.delete(options, :db_side_batch_insertions))
  end

  defp parse_options(params, %{allow_experimental_object_type: true} = options) do
    Map.put(params, "allow_experimental_object_type", 1)
    |> parse_options(Map.delete(options, :allow_experimental_object_type))
  end

  defp parse_options(params, _options), do: params

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
