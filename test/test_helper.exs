ExUnit.start()

defmodule PillarTestPoolWorker do
  use Pillar,
    connection_strings: List.wrap(Application.get_env(:pillar, :connection_url)),
    name: __MODULE__,
    pool_size: 3
end

PillarTestPoolWorker.start_link()
