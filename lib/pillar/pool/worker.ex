defmodule Pillar.Pool.Worker do
  use GenServer

  def start_link(connection_string) do
    GenServer.start_link(__MODULE__, connection_string)
  end

  def init(connection_string) do
    {:ok, Pillar.Connection.new(connection_string)}
  end

  def handle_call({query, params}, _from, state) do
    {:ok, result} = Pillar.query(state, query, params)
    {:reply, {:ok, result}, state}
  end

  def handle_cast({query, params}, state) do
    {:ok, _result} = Pillar.query(state, query, params)
    {:noreply, state}
  end
end
