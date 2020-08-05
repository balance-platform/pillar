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
end
