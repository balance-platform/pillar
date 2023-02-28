defmodule Pillar.Application do
  use Application

  def default_finch_instance, do: PillarFinchPool

  @impl true
  def start(_type, _args) do
    finch_instance_name = default_finch_instance()

    children = [
      {Finch,
       name: finch_instance_name,
       pools: %{
         :default => [size: 10]
       }}
    ]

    :ets.new(:pillar_finch_instances, [:set, :public, :named_table, read_concurrency: true])

    opts = [strategy: :one_for_one, name: Pillar.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
