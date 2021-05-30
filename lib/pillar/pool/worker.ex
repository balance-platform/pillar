defmodule Pillar.Pool.Worker do
  @moduledoc false

  use GenServer

  def start_link(connections) do
    GenServer.start_link(__MODULE__, connections)
  end

  def init(connections) when is_list(connections) do
    connection = Enum.random(connections)
    {:ok, connection}
  end

  def handle_call({command, query, params, options}, _from, connection) do
    result = handle_command(connection, command, query, params, options)
    {:reply, result, connection}
  end

  def handle_cast({command, query, params, options}, connection) do
    {:ok, _result} = handle_command(connection, command, query, params, options)
    {:noreply, connection}
  end

  defp handle_command(connection, command, query, params, options)
       when command in [:insert, :select, :query] do
    case command do
      :insert -> Pillar.insert(connection, query, params, options)
      :select -> Pillar.select(connection, query, params, options)
      :query -> Pillar.query(connection, query, params, options)
    end
  end

  defp handle_command(connection, command, table_name, record_or_records, options)
       when command in [:insert_to_table] do
    Pillar.insert_to_table(connection, table_name, record_or_records, options)
  end
end
