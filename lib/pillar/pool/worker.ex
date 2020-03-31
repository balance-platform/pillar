defmodule Pillar.Pool.Worker do
  use GenServer

  def start_link(connection_string) do
    GenServer.start_link(__MODULE__, connection_string)
  end

  def init(connection_string) do
    {:ok, Pillar.Connection.new(connection_string)}
  end

  def handle_call({query, params, options}, _from, state) do
    result = Pillar.query(state, query, params, options)
    {:reply, result, state}
  end

  def handle_cast({query, params, options}, state) do
    {:ok, _result} = Pillar.query(state, query, params, options)
    {:noreply, state}
  end
end
