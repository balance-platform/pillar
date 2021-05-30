ExUnit.start()

defmodule PillarTestPoolWorkerTM do
  @url Application.get_env(:pillar, :connection_url)

  use Pillar,
    connections: List.wrap(Pillar.Connection.new(@url, Pillar.HttpClient.TeslaMintAdapter)),
    name: __MODULE__,
    pool_size: 3
end

defmodule PillarTestPoolWorkerHC do
  @url Application.get_env(:pillar, :connection_url)

  use Pillar,
    connections: List.wrap(Pillar.Connection.new(@url, Pillar.HttpClient.HttpcAdapter)),
    name: __MODULE__,
    pool_size: 3
end

PillarTestPoolWorkerTM.start_link()
PillarTestPoolWorkerHC.start_link()
