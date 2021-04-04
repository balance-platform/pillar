defmodule Pillar.BulkInsertBuffer do
  @moduledoc """
  This module provides functionality for bulk inserts and buffering records

  ```elixir
  defmodule BulkToLogs do
    use Pillar.BulkInsertBuffer,
      pool: ClickhouseMaster,
      table_name: "logs",
      interval_between_inserts_in_seconds: 5,
      on_errors: &__MODULE__.dump_to_file/2

    def dump_to_file(_result, records) do
      File.write("bad_inserts/#{DateTime.utc_now()}", inspect(records))
    end
  end
  ```

  ```elixir
  :ok = BulkToLogs.insert(%{value: "online", count: 133, datetime: DateTime.utc_now()})
  :ok = BulkToLogs.insert(%{value: "online", count: 134, datetime: DateTime.utc_now()})
  :ok = BulkToLogs.insert(%{value: "online", count: 132, datetime: DateTime.utc_now()})
  ....

  # all this records will be inserted with 5 second interval
  ```
  """

  defmacro __using__(options) do
    quote do
      use GenServer
      import Supervisor.Spec

      def start_link(_any \\ nil) do
        name = __MODULE__
        pool = Keyword.get(unquote(options), :pool)
        table_name = Keyword.get(unquote(options), :table_name)

        if is_nil(pool) do
          raise "#{__MODULE__} pool is not set"
        end

        if is_nil(table_name) do
          raise "#{__MODULE__} table_name is not set"
        end

        errors_handle_function =
          Keyword.get(unquote(options), :on_errors, fn _any, _records -> :ok end)

        records = []

        GenServer.start_link(__MODULE__, {pool, table_name, records, errors_handle_function},
          name: name
        )
      end

      def init(state) do
        schedule_work()
        {:ok, state}
      end

      def insert(data) when is_map(data) do
        GenServer.cast(__MODULE__, {:insert, data})
      end

      def force_bulk_insert do
        GenServer.call(__MODULE__, :do_insert)
      end

      def records_for_bulk_insert() do
        GenServer.call(__MODULE__, :records_for_bulk_insert)
      end

      def handle_call(:do_insert, _from, state) do
        new_state = do_bulk_insert(state)

        {:reply, :ok, new_state}
      end

      def handle_cast(
            {:insert, data},
            {pool, table_name, records, errors_handle_function} = state
          ) do
        {:noreply, {pool, table_name, List.wrap(data) ++ records, errors_handle_function}}
      end

      def handle_call(
            :records_for_bulk_insert,
            _from,
            {_pool, _table_name, records, _errors_handle_function} = state
          ) do
        {:reply, records, state}
      end

      def handle_info(:cron_like_records, state) do
        new_state = do_bulk_insert(state)
        schedule_work()
        {:noreply, new_state}
      end

      defp schedule_work do
        # 5 seconds by default
        seconds = Keyword.get(unquote(options), :interval_between_inserts_in_seconds, 5)
        Process.send_after(self(), :cron_like_records, :timer.seconds(seconds))
      end

      defp do_bulk_insert({_pool, _table_name, [], _error_handle_function} = state) do
        state
      end

      defp do_bulk_insert({pool, table_name, records, error_handle_function} = state) do
        result = pool.insert_to_table(table_name, records)

        case result do
          {:error, _reason} -> error_handle_function.(result, records)
          _another -> nil
        end

        # Build state back, without records
        {
          pool,
          table_name,
          [],
          error_handle_function
        }
      end
    end
  end
end
