defmodule Pillar.Ecto.ConnMod do
  @moduledoc false

  use DBConnection

  def connect(_) do
    conn = Pillar.Connection.new("http://localhost:8123")
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
    IO.inspect(["here--------------", query])

    case Pillar.query(state.conn, query.statement <> " FORMAT JSON") |> IO.inspect() do
      {:error, reason} ->
        {:error, reason, state}

      {:ok, result} ->
        IO.inspect(["RETURN CLICKHOUSE", result])

        {
          :ok,
          query,
          to_result(result),
          state
        }
    end
  end

  defp to_result(res) do
    case res do
      xs when is_list(xs) -> %{num_rows: Enum.count(xs), rows: Enum.map(xs, &to_row/1)}
      nil -> %{num_rows: 0, rows: [nil]}
      _ -> %{num_rows: 1, rows: [res]}
    end
    |> IO.inspect()
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
