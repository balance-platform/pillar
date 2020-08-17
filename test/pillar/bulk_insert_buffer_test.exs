defmodule Pillar.BulkInsertBufferTest do
  use ExUnit.Case

  alias Pillar.BulkInsertBuffer
  alias Pillar.Connection

  @ts DateTime.utc_now() |> DateTime.to_unix()
  @table_name "logs_#{@ts}"

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
      CREATE TABLE IF NOT EXISTS #{@table_name} (
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
    assert [^r1, ^r2] = BulkToLogs.records_for_bulk_insert()
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

  test "#generate_insert_query/3" do
    values = [
      %{field_1: 1, field_2: 2, field_3: 3},
      %{field_1: nil, field_2: 2, field_3: 4},
      %{field_1: "1"},
      %{field_2: 2},
      %{field_3: 4},
      %{}
    ]

    table_name = "example"

    assert [
             "INSERT INTO",
             "example",
             "FORMAT JSONEachRow",
             "{\"field_1\":\"1\",\"field_2\":\"2\",\"field_3\":\"3\"} {\"field_2\":\"2\",\"field_3\":\"4\"} {\"field_1\":\"1\"} {\"field_2\":\"2\"} {\"field_3\":\"4\"} {}"
           ] ==
             String.split(BulkInsertBuffer.generate_insert_query(table_name, values), "\n")
  end
end
