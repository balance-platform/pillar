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

  describe "If bulk insert ends by error, handle function works" do
    defmodule BulkToLogsWithErrorHandler do
      use BulkInsertBuffer,
        pool: PillarTestPoolWorker,
        table_name: "logs",
        interval_between_inserts_in_seconds: 5,
        on_errors: &__MODULE__.dump_to_file/2

      def dump_to_file(_result, records) do
        File.write("errors_from_bulk_insert_tests", inspect(records))
      end
    end

    test "on_errors option, dump_to_file -> saves data to file", %{conn: conn} do
      %{"major" => major, "minor" => minor} = version(conn)

      if major >= 22 && minor >= 6 do
        # Clickhouse of this version doesn't return errors on insert becouse of internal queue
        # skip test scenario on this version and newer
        :ok
      else
        {:ok, _pid} = BulkToLogsWithErrorHandler.start_link()

        BulkToLogsWithErrorHandler.insert(%{a: "hello", b: "honey"})
        BulkToLogsWithErrorHandler.force_bulk_insert()

        assert File.read!("errors_from_bulk_insert_tests") == "[%{a: \"hello\", b: \"honey\"}]"

        File.rm!("errors_from_bulk_insert_tests")
      end
    end

    test "on_errors option, doesn't saves data, if there were no errors" do
      {:ok, _pid} = BulkToLogsWithErrorHandler.start_link()

      BulkToLogsWithErrorHandler.insert(%{
        value: "online",
        count: 133,
        datetime: DateTime.utc_now()
      })

      BulkToLogsWithErrorHandler.force_bulk_insert()

      assert File.exists?("errors_from_bulk_insert_tests") == false
    end
  end

  defp version(conn) do
    {:ok, [%{"version()" => version}]} = Pillar.select(conn, "SELECT version()")
    [major, minor, fix, build] = String.split(version, ".")

    %{
      "major" => String.to_integer(major),
      "minor" => String.to_integer(minor),
      "fix" => String.to_integer(fix),
      "build" => String.to_integer(build)
    }
  end
end
