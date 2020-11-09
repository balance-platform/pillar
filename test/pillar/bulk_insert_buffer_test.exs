defmodule Pillar.BulkInsertBufferTest do
  use ExUnit.Case

  alias Pillar.BulkInsertBuffer
  alias Pillar.Connection

  defmodule BulkToLogs do
    use BulkInsertBuffer,
      pool: PillarTestPoolWorker,
      table_name: "logs",
      interval_between_inserts_in_seconds: 5
  end

  setup do
    connection_url = Application.get_env(:pillar, :connection_url)
    connection = Connection.new(connection_url)

    create_table_sql = """
      CREATE TABLE IF NOT EXISTS logs (
        datetime DateTime,
        value String,
        count Int32
      ) ENGINE = Memory
    """

    {:ok, _} = Pillar.query(connection, create_table_sql)

    {:ok, _pid} = BulkToLogs.start_link()

    {:ok, %{conn: connection}}
  end

  test "Insert function adds data to genserver state" do
    assert [] == BulkToLogs.records_for_bulk_insert()

    r1 = %{
      value: "online",
      count: 133,
      datetime: DateTime.utc_now()
    }

    r2 = %{
      value: "offline",
      count: 20,
      datetime: DateTime.utc_now()
    }

    assert :ok = BulkToLogs.insert(r1)

    assert [^r1] = BulkToLogs.records_for_bulk_insert()
    assert :ok = BulkToLogs.insert(r2)
    records_for_bulk_insert = BulkToLogs.records_for_bulk_insert()
    assert r1 in records_for_bulk_insert
    assert r2 in records_for_bulk_insert
  end

  test "Force insert" do
    assert :ok =
             BulkToLogs.insert(%{
               value: "online",
               count: 133,
               datetime: DateTime.utc_now()
             })

    assert :ok =
             BulkToLogs.insert(%{
               value: "online",
               count: 11,
               datetime: DateTime.utc_now()
             })

    assert :ok =
             BulkToLogs.insert(%{
               value: "online",
               count: 12,
               datetime: DateTime.utc_now()
             })

    assert [_r1, _r2, _r3] = BulkToLogs.records_for_bulk_insert()
    assert :ok = BulkToLogs.force_bulk_insert()
    assert [] = BulkToLogs.records_for_bulk_insert()
  end

  test "automatic inserts by time" do
    BulkToLogs.insert(%{
      value: "online",
      count: 11,
      datetime: DateTime.utc_now()
    })

    assert [_record] = BulkToLogs.records_for_bulk_insert()

    :timer.sleep(6_000)

    assert [] = BulkToLogs.records_for_bulk_insert()
  end
end
