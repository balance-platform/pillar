defmodule Pillar.Ecto.ConnMod do
  @moduledoc false

  use DBConnection

  alias Pillar.Connection
  alias Pillar.HttpClient
  alias Pillar.HttpClient.Response
  alias Pillar.HttpClient.TransportError
  alias Pillar.Ecto.Helpers

  def connect(opts) do
    url = Keyword.get(opts, :url, "http://localhost:8123")
    conn = Pillar.Connection.new(url)
    {:ok, %{conn: conn}}
  end

  def disconnect(_err, _state) do
    :ok
  end

  @doc false
  def ping(state) do
    {:ok, state}
  end

  @doc false
  def reconnect(new_opts, state) do
    with :ok <- disconnect("Reconnecting", state),
         do: connect(new_opts)
  end

  @doc false
  def checkin(state) do
    {:ok, state}
  end

  @doc false
  def checkout(state) do
    {:ok, state}
  end

  @doc false
  def handle_status(_, state) do
    {:idle, state}
  end

  @doc false
  def handle_prepare(query, _, state) do
    {:ok, query, state}
  end

  @doc false
  def handle_execute(query, _params, _opts, state) do
    params = Enum.join(query.params, "&")

    url =
      state.conn
      |> Connection.url_from_connection()

    url = url <> "&" <> params

    url
    |> HttpClient.post(
      query.statement <>
        " FORMAT JSONCompactEachRowWithNamesAndTypes SETTINGS date_time_output_format='iso', output_format_json_quote_64bit_integers=0",
      timeout: 60_000
    )
    |> parse()
    |> case do
      {:error, reason} ->
        {:error, reason, state}

      {:ok, body} ->
        [types | rows] =
          body
          |> String.split("\n", trim: true)
          |> Enum.map(&Jason.decode!(&1))
          |> Enum.drop(1)

        rows =
          rows
          |> Enum.map(fn row ->
            Enum.zip(row, types)
            |> Enum.map(fn {data, type} ->
              Helpers.parse_type(type, data)
            end)
          end)

        {
          :ok,
          query,
          to_result(rows),
          state
        }
    end
  end

  defp parse(%Response{status_code: 200, body: body}) do
    {:ok, body}
  end

  defp parse(%Response{status_code: _any, body: _body} = resp) do
    {:error, resp}
  end

  defp parse(%TransportError{} = error) do
    {:error, error}
  end

  defp parse(%RuntimeError{} = error) do
    {:error, error}
  end

  defp to_result(res) do
    case res do
      xs when is_list(xs) -> %{num_rows: Enum.count(xs), rows: Enum.map(xs, &to_row/1)}
      nil -> %{num_rows: 0, rows: [nil]}
      _ -> %{num_rows: 1, rows: [res]}
    end
  end

  defp to_row(xs) when is_list(xs), do: xs
  defp to_row(x) when is_map(x), do: Map.values(x)
  defp to_row(x), do: x

  @doc false
  def handle_declare(_query, _params, _opts, state) do
    {:error, :cursors_not_supported, state}
  end

  @doc false
  def handle_deallocate(_query, _cursor, _opts, state) do
    {:error, :cursors_not_supported, state}
  end

  def handle_fetch(_query, _cursor, _opts, state) do
    {:error, :cursors_not_supported, state}
  end

  @doc false
  def handle_begin(_opts, state) do
    {:error, :cursors_not_supported, state}
  end

  @doc false
  def handle_close(_query, _opts, state) do
    {:error, :cursors_not_supported, state}
  end

  @doc false
  def handle_commit(_opts, state) do
    {:error, :cursors_not_supported, state}
  end

  @doc false
  def handle_info(_msg, state) do
    {:error, :cursors_not_supported, state}
  end

  @doc false
  def handle_rollback(_opts, state) do
    {:error, :cursors_not_supported, state}
  end
end
