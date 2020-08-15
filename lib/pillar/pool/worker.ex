defmodule Pillar.Pool.Worker do
  @moduledoc false

  use GenServer
  alias Pillar.Connection

  def start_link(connection_list) when is_list(connection_list) do
    connections =
      connection_list
      |> Enum.map(&try_transform_connection_or_string_to_struct/1)
      |> Enum.reject(&is_nil/1)

    GenServer.start_link(__MODULE__, connections)
  end

  def init(connections) when is_list(connections) and length(connections) > 0 do
    connection = Enum.random(connections)
    {:ok, connection}
  end

  def handle_call({:select, query, params, options}, _from, state) do
    result = Pillar.select(state, query, params, options)
    {:reply, result, state}
  end

  def handle_call({:query, query, params, options}, _from, state) do
    result = Pillar.query(state, query, params, options)
    {:reply, result, state}
  end

  def handle_call({:insert, query, params, options}, _from, state) do
    result = Pillar.insert(state, query, params, options)
    {:reply, result, state}
  end

  def handle_cast({:insert, query, params, options}, state) do
    {:ok, _result} = Pillar.insert(state, query, params, options)
    {:noreply, state}
  end

  def handle_cast({:query, query, params, options}, state) do
    {:ok, _result} = Pillar.query(state, query, params, options)
    {:noreply, state}
  end

  defp try_transform_connection_or_string_to_struct(connection_value) do
    # expected connection_string (http://localhost:8123) or Pillar.Connection struct,
    # returned value is Pillar.Connection or nil in other cases

    cond do
      String.valid?(connection_value) ->
        Connection.new(connection_value)

      %Connection{} = connection_value ->
        connection_value

      true ->
        nil
    end
  end
end
