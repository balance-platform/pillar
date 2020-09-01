defmodule Pillar.BulkInsertBuffer do
  @moduledoc """
  This module provides functionality for bulk inserts and buffering records

  ```elixir
    defmodule BulkToLogs do
      use Pillar.BulkInsertBuffer,
        pool: ClickhouseMaster,
        table_name: "logs",
        interval_between_inserts_in_seconds: 5
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
  alias Pillar.TypeConvert.ToClickhouseJson

  def generate_insert_query(table_name, values) do
    new_values = Enum.map(values, &convert_values_to_clickhouse/1)

    sql_strings = [
      "INSERT INTO",
      table_name,
      "FORMAT JSONEachRow",
      Enum.join(Enum.map(new_values, &Jason.encode!/1), " ")
    ]

    Enum.join(sql_strings, "\n")
  end

  defp convert_values_to_clickhouse(map) do
    map
    |> Enum.reject(fn {_key, value} -> is_nil(value) end)
    |> Enum.map(fn {key, value} ->
      {key, ToClickhouseJson.convert(value)}
    end)
    |> Map.new()
  end

  defmacro __using__(
             pool: pool_module,
             table_name: table_name,
             interval_between_inserts_in_seconds: seconds
           ) do
    quote do
      use GenServer
      import Supervisor.Spec
      alias Pillar.BulkInsertBuffer

      def start_link(_any \\ nil) do
        name = unquote(__MODULE__)
        pool = unquote(pool_module)
        table_name = unquote(table_name)
        records = []
        GenServer.start_link(__MODULE__, {pool, table_name, records}, name: name)
      end

      def init(state) do
        schedule_work()
        {:ok, state}
      end

      def insert(data) when is_map(data) do
        GenServer.cast(unquote(__MODULE__), {:insert, data})
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

      def handle_cast({:insert, data}, {pool, table_name, records} = state) do
        {:noreply, {pool, table_name, records ++ List.wrap(data)}}
      end

      def handle_call(
            :records_for_bulk_insert,
            _from,
            {_pool, _table_name, records} = state
          ) do
        {:reply, records, state}
      end

      def handle_info(:cron_like_records, state) do
        new_state = do_bulk_insert(state)
        schedule_work()
        {:noreply, new_state}
      end

      defp schedule_work do
        seconds = unquote(seconds)
        Process.send_after(self(), :cron_like_records, :timer.seconds(seconds))
      end

      defp do_bulk_insert({_pool, _table_name, []} = state) do
        state
      end

      defp do_bulk_insert({pool, table_name, records} = state) do
        sql = BulkInsertBuffer.generate_insert_query(table_name, records)

        {:ok, _} = pool.query(sql, %{})

        {
          pool,
          table_name,
          []
        }
      end
    end
  end
end
