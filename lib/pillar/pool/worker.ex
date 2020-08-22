defmodule Pillar.Pool.Worker do
  @moduledoc false

  use GenServer

  def start_link(connection_string) do
    GenServer.start_link(__MODULE__, connection_string)
  end

  def init(connection_string_list) when is_list(connection_string_list) do
    connection_string = Enum.random(connection_string_list)
    {:ok, Pillar.Connection.new(connection_string)}
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
end
