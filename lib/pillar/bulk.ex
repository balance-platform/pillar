defmodule Pillar.Bulk do
  alias Pillar.Bulk.Helper

  defmacro __using__(
             pool: pool_module,
             table_name: table_name,
             interval_between_inserts_in_seconds: seconds
           ) do
    quote do
      use GenServer
      import Supervisor.Spec

      def start_link(_any \\ nil) do
        name = unquote(__MODULE__)
        pool = unquote(pool_module)
        table_name = unquote(table_name)
        columns = Helper.columns(pool, table_name)
        inserts = []
        GenServer.start_link(__MODULE__, {pool, table_name, columns, inserts}, name: name)
      end

      def init(state) do
        schedule_work()
        {:ok, state}
      end

      def columns() do
        GenServer.call(unquote(__MODULE__), :columns)
      end

      def insert(data) when is_map(data) do
        GenServer.call(unquote(__MODULE__), {:insert, data})
      end

      def force_bulk_insert do
        GenServer.call(unquote(__MODULE__), :do_insert)
      end

      def records_for_bulk_insert() do
        GenServer.call(unquote(__MODULE__), :records_for_bulk_insert)
      end

      def handle_call(:do_insert, _from, state) do
        new_state = do_bulk_insert(state)

        {:reply, :ok, new_state}
      end

      def handle_call(:columns, _from, {_pool, _table_name, columns, _inserts} = state) do
        {:reply, columns, state}
      end

      def handle_call({:insert, data}, _from, {pool, table_name, columns, inserts} = state) do
        {:reply, :ok, {pool, table_name, columns, inserts ++ List.wrap(data)}}
      end

      def handle_call(
            :records_for_bulk_insert,
            _from,
            {_pool, _table_name, _columns, inserts} = state
          ) do
        {:reply, inserts, state}
      end

      def handle_info(:cron_like_inserts, state) do
        new_state = do_bulk_insert(state)
        schedule_work()
        {:noreply, new_state}
      end

      defp schedule_work do
        seconds = unquote(seconds)
        Process.send_after(self(), :cron_like_inserts, :timer.seconds(seconds))
      end

      defp do_bulk_insert({pool, table_name, columns, inserts} = state) do
        {sql, data} = Helper.generate_bulk_insert_query(table_name, columns, inserts)

        {:ok, _} = pool.query(sql, data)

        {
          pool,
          table_name,
          columns,
          []
        }
      end
    end
  end
end
