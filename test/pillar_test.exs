defmodule PillarTest do
  use ExUnit.Case
  doctest Pillar
  alias Pillar.Connection

  require Logger

  @timestamp DateTime.to_unix(DateTime.utc_now())

  defmodule PillarWorker do
    use Pillar,
      connection_strings: List.wrap(Application.get_env(:pillar, :connection_url)),
      name: __MODULE__,
      pool_size: 3
  end

  setup do
    Calendar.put_time_zone_database(Tzdata.TimeZoneDatabase)

    connection_url = Application.get_env(:pillar, :connection_url)
    connection = Connection.new(connection_url)

    {:ok, %{conn: connection}}
  end

  setup_all do
    start_supervised!(PillarWorker)
    :ok
  end

  describe "GenServer tests" do
    test "#query - without passing connection" do
      assert PillarWorker.query("SELECT 1 FORMAT JSON") == {:ok, [%{"1" => 1}]}
    end

    test "#query - timeout tests" do
      {:error, %Pillar.HttpClient.TransportError{reason: reason}} =
        PillarWorker.query("SELECT sleep(1)", %{}, %{timeout: 0})

      assert inspect(reason) =~ ~r/timeout/
    end

    test "#query - timeout tests with 3s" do
      {:error, %Pillar.HttpClient.TransportError{reason: reason}} =
        PillarWorker.query("SELECT sleep(3)", %{}, %{timeout: 3_000})

      assert inspect(reason) =~ ~r/timeout/
    end

    test "#async_query" do
      assert PillarWorker.async_query("SELECT 1") == :ok
    end

    test "#async_insert" do
      create_table_sql = """
        CREATE TABLE IF NOT EXISTS async_insert_test_#{@timestamp} (field FixedString(10)) ENGINE = Memory
      """

      insert_query_sql = """
        INSERT INTO async_insert_test_#{@timestamp} VALUES ('0123456789')
      """

      assert PillarWorker.query(create_table_sql) == {:ok, ""}
      assert PillarWorker.async_insert(insert_query_sql) == :ok
      :timer.sleep(100)

      assert {:ok, [%{"field" => "0123456789"}]} =
               PillarWorker.select("SELECT * FROM async_insert_test_#{@timestamp}")
    end

    test "#insert with VALUES syntax" do
      create_table_sql = """
        CREATE TABLE IF NOT EXISTS insert_with_values_#{@timestamp} (field FixedString(10)) ENGINE = Memory
      """

      insert_query_sql = """
        INSERT INTO insert_with_values_#{@timestamp} (field) VALUES ('0123456789')
      """

      assert PillarWorker.query(create_table_sql) == {:ok, ""}
      assert PillarWorker.insert(insert_query_sql) == {:ok, ""}

      assert {:ok, [%{"field" => "0123456789"}]} =
               PillarWorker.select("SELECT * FROM insert_with_values_#{@timestamp}")
    end

    test "#insert with SELECT syntax" do
      create_table_sql = """
        CREATE TABLE IF NOT EXISTS insert_with_select_#{@timestamp} (field FixedString(10)) ENGINE = Memory
      """

      insert_query_sql = """
        INSERT INTO insert_with_select_#{@timestamp} (field) SELECT '0123456789'
      """

      assert PillarWorker.query(create_table_sql) == {:ok, ""}
      assert PillarWorker.insert(insert_query_sql) == {:ok, ""}

      assert {:ok, [%{"field" => "0123456789"}]} =
               PillarWorker.select("SELECT * FROM insert_with_select_#{@timestamp}")
    end
  end

  describe "Finch instance tests" do
    test "Uses the default Finch instance when no module is specified", %{conn: conn} do
      ref = :telemetry_test.attach_event_handlers(self(), [[:finch, :request, :start]])
      finch_instance = Pillar.Application.default_finch_instance()
      assert Pillar.query(conn, "SELECT 1 FORMAT JSON") == {:ok, [%{"1" => 1}]}

      assert_received {
        [:finch, :request, :start],
        ^ref,
        _measurement,
        %{
          name: ^finch_instance
        }
      }
    end

    test "Uses the correct Finch instance when using module" do
      ref = :telemetry_test.attach_event_handlers(self(), [[:finch, :request, :start]])
      assert PillarWorker.query("SELECT 1 FORMAT JSON") == {:ok, [%{"1" => 1}]}
      finch_instance = PillarTest.PillarWorkerFinchInstance

      assert_received {
        [:finch, :request, :start],
        ^ref,
        _measurement,
        %{
          name: ^finch_instance
        }
      }
    end
  end

  describe "injection tests" do
    test "@LamaLover (Thanks for example)", %{conn: conn} do
      assert {:ok, [%{"'(SELECT {primary} from table)'" => "(SELECT {primary} from table)"}]} ==
               Pillar.select(conn, "select {a00}", %{
                 a00: "(SELECT {primary} from table)",
                 primary: "id"
               })
    end

    test "-- comment string", %{conn: conn} do
      # In success injection result should equal 2, but if returns string '--\n2', then injection failed
      assert {:ok, [%{"res" => "--\n2"}]} ==
               Pillar.select(conn, "select\n{a00} as res", %{
                 a00: "--\n2"
               })
    end

    test "; with new query", %{conn: conn} do
      # In success injection result should equal 3, and column == INJECTED, but if returns string res, then injection failed
      assert {:ok, [%{"res" => "'; SELECT 3 as INJECTED"}]} ==
               Pillar.select(conn, "select {arg} as res", %{arg: "'; SELECT 3 as INJECTED"})
    end
  end

  describe "data types tests" do
    test "UUID test", %{conn: conn} do
      assert {:ok, [%{"uuid" => uuid}]} = Pillar.select(conn, "SELECT generateUUIDv4() as uuid")

      assert String.valid?(uuid) && String.length(uuid) == 36
    end

    test "Array test", %{conn: conn} do
      assert {:ok, [%{"array" => [1, 2, 3]}]} = Pillar.select(conn, "SELECT [1, 2, 3] as array")

      assert {:ok, [%{"array" => ["1", "2", "3"]}]} =
               Pillar.select(conn, "SELECT ['1', '2', '3'] as array")

      assert {:ok, [%{"array" => [%DateTime{}, %DateTime{}, nil]}]} =
               Pillar.select(conn, "SELECT [now(), now(), NULL] as array")
    end

    test "String test", %{conn: conn} do
      sql = "SELECT 'ИВАН МИХАЛЫЧ' name FORMAT JSON"

      assert {:ok, [%{"name" => "ИВАН МИХАЛЫЧ"}]} = Pillar.query(conn, sql)
    end

    test "FixedString test", %{conn: conn} do
      create_table_sql = """
        CREATE TABLE IF NOT EXISTS fixed_string_table (field FixedString(10)) ENGINE = Memory
      """

      insert_query_sql = """
        INSERT INTO fixed_string_table VALUES ('0123456789')
      """

      assert {:ok, ""} = Pillar.query(conn, create_table_sql)
      assert {:ok, ""} = Pillar.insert(conn, insert_query_sql)

      assert {:ok, [%{"field" => "0123456789"}]} =
               Pillar.select(conn, "SELECT * FROM fixed_string_table LIMIT 1")
    end

    test "Enum8 test", %{conn: conn} do
      create_table_sql = """
        CREATE TABLE IF NOT EXISTS enum8_table (field Enum8('VAL1' = 0, 'VAL2' = 1)) ENGINE = Memory
      """

      insert_query_sql = """
        INSERT INTO enum8_table SELECT 'VAL1' UNION ALL SELECT 'VAL2'
      """

      assert {:ok, ""} = Pillar.query(conn, create_table_sql)
      assert {:ok, ""} = Pillar.query(conn, insert_query_sql)

      assert {:ok, [%{"field" => "VAL1"}]} =
               Pillar.select(conn, "SELECT * FROM enum8_table ORDER BY field LIMIT 1")
    end

    test "LowCardinality(String)", %{conn: conn} do
      create_table_sql = """
      CREATE TABLE IF NOT EXISTS lc_table (field LowCardinality(String)) ENGINE = Memory
      """

      insert_query_sql = """
      INSERT INTO lc_table SELECT 'val'
      """

      assert {:ok, ""} = Pillar.query(conn, create_table_sql)
      assert {:ok, ""} = Pillar.query(conn, insert_query_sql)

      assert {:ok, [%{"field" => "val"}]} =
               Pillar.query(conn, "SELECT * FROM lc_table LIMIT 1 FORMAT JSON")
    end

    test "LowCardinality(UInt8)", %{conn: conn} do
      conn = %Pillar.Connection{conn | allow_suspicious_low_cardinality_types: true}

      table_name = "lc_table_uint_8_#{@timestamp}"

      create_table_sql = """
      CREATE TABLE IF NOT EXISTS #{table_name} (field LowCardinality(UInt8)) ENGINE = Memory
      """

      insert_query_sql = """
      INSERT INTO #{table_name} SELECT 32
      """

      assert {:ok, ""} = Pillar.query(conn, create_table_sql)
      assert {:ok, ""} = Pillar.query(conn, insert_query_sql)

      assert {:ok, [%{"field" => 32}]} =
               Pillar.query(conn, "SELECT * FROM #{table_name} LIMIT 1 FORMAT JSON")
    end

    test "LowCardinality(Float64)", %{conn: conn} do
      conn = %Pillar.Connection{conn | allow_suspicious_low_cardinality_types: true}

      table_name = "lc_table_float_64_#{@timestamp}"

      create_table_sql = """
      CREATE TABLE IF NOT EXISTS #{table_name} (field LowCardinality(Float64)) ENGINE = Memory
      """

      insert_query_sql = """
      INSERT INTO #{table_name} SELECT 1994.1994
      """

      assert {:ok, ""} = Pillar.query(conn, create_table_sql)
      assert {:ok, ""} = Pillar.query(conn, insert_query_sql)

      assert {:ok, [%{"field" => 1994.1994}]} =
               Pillar.query(conn, "SELECT * FROM #{table_name} LIMIT 1 FORMAT JSON")
    end

    test "SimpleAggregateFunction(groupArrayArray, Array(Array(String)))", %{conn: conn} do
      drop_table_sql = """
      DROP TABLE IF EXISTS saf_table
      """

      create_table_sql = """
      CREATE TABLE IF NOT EXISTS saf_table
      (
        `id` String,
        `strings_array_array` SimpleAggregateFunction(groupArrayArray, Array(Array(String)))
      )
      ENGINE = AggregatingMergeTree
      ORDER BY (id)
      """

      insert_query_sql = """
      INSERT INTO saf_table VALUES ('a', array(array('foo', 'bar', 'baz')))
      """

      select_query_sql = """
      SELECT strings_array_array FROM saf_table
      """

      assert {:ok, ""} = Pillar.query(conn, drop_table_sql)
      assert {:ok, ""} = Pillar.query(conn, create_table_sql)
      assert {:ok, ""} = Pillar.query(conn, insert_query_sql)

      assert {:ok, [%{"strings_array_array" => [["foo", "bar", "baz"]]}]} =
               Pillar.select(conn, select_query_sql)

      assert {:ok, ""} = Pillar.query(conn, drop_table_sql)
    end

    test "Date test", %{conn: conn} do
      sql = "SELECT today()"

      assert {:ok, [%{"today()" => %Date{}}]} = Pillar.select(conn, sql)
    end

    test "empty Date test", %{conn: conn} do
      table_name = "lc_table_empty_date_#{@timestamp}"

      create_table_sql = """
      CREATE TABLE IF NOT EXISTS #{table_name} (field Nullable(Date)) ENGINE = Memory
      """

      insert_query_sql = """
      INSERT INTO #{table_name} SELECT null
      """

      assert {:ok, ""} = Pillar.query(conn, create_table_sql)
      assert {:ok, ""} = Pillar.query(conn, insert_query_sql)

      assert {:ok, [%{"field" => nil}]} =
               Pillar.query(conn, "SELECT * FROM #{table_name} LIMIT 1 FORMAT JSON")
    end

    test "Date32 test", %{conn: conn} do
      sql = "SELECT toDate32(now()) AS Date32"

      case Pillar.select(conn, sql) do
        {:error, %Pillar.HttpClient.Response{body: error}} ->
          assert error =~ ~r/Unknown function toDate32/

        {:ok, [%{"Date32" => date32_result}]} ->
          assert %Date{} = date32_result

          table_name = "date32_test_#{@timestamp}"

          create_table_sql = """
          CREATE TABLE IF NOT EXISTS #{table_name} (field Date32) ENGINE = Memory
          """

          assert {:ok, ""} = Pillar.query(conn, create_table_sql)

          assert {:ok, ""} =
                   Pillar.query(conn, "INSERT INTO #{table_name} SELECT {date}", %{
                     date: Date.utc_today()
                   })

          assert {:ok, [%{"field" => %Date{}}]} =
                   Pillar.select(conn, "SELECT * FROM #{table_name} LIMIT 1")
      end
    end

    test "DateTime test", %{conn: conn} do
      sql = "SELECT now()"

      assert {:ok, [%{"now()" => %DateTime{}}]} = Pillar.select(conn, sql)
    end

    test "Insert DateTime test", %{conn: conn} do
      table_name = "datetime_test_#{@timestamp}"

      create_table_sql = """
      CREATE TABLE IF NOT EXISTS #{table_name} (field DateTime) ENGINE = Memory
      """

      assert {:ok, ""} = Pillar.query(conn, create_table_sql)

      assert {:ok, ""} =
               Pillar.query(conn, "INSERT INTO #{table_name} SELECT {date}", %{
                 date: DateTime.utc_now()
               })
    end

    test "DateTime with Timezone", %{conn: conn} do
      sql =
        "SELECT toTimeZone(toDateTime('2021-12-20 06:00:00', 'UTC'), 'Europe/Moscow') AS timezone_datetime"

      assert {:ok, [%{"timezone_datetime" => datetime_or_error}]} = Pillar.select(conn, sql)
      # it's OK to return error for elixir lower 1.11
      if datetime_or_error == {:error, "feature needs elixir v1.11 minimum"} do
        assert true
      else
        assert DateTime.to_string(datetime_or_error) ==
                 "2021-12-20 09:00:00+03:00 MSK Europe/Moscow"
      end
    end

    test "Decimal test", %{conn: conn} do
      create_table_sql = """
        CREATE TABLE IF NOT EXISTS decimal_table_#{@timestamp} (field Decimal64(2)) ENGINE = Memory
      """

      insert_query_sql = """
        INSERT INTO decimal_table_#{@timestamp} VALUES (500000.05)
      """

      assert {:ok, ""} = Pillar.query(conn, create_table_sql)
      assert {:ok, ""} = Pillar.query(conn, insert_query_sql)

      assert {:ok, [%{"field" => 500_000.05}]} =
               Pillar.select(conn, "SELECT * FROM decimal_table_#{@timestamp} LIMIT 1")
    end

    test "Float tests", %{conn: conn} do
      sql = ~s(
        SELECT
          -127.0 Float32,
          -92233720368.31 Float64
      )

      assert Pillar.select(conn, sql) ==
               {:ok, [%{"Float32" => -127, "Float64" => -92_233_720_368.31}]}
    end

    test "Integer tests", %{conn: conn} do
      sql = ~s(
        SELECT
          -127 Int8,
          -32768 Int16,
          -2147483648 Int32,
          -9223372036854775808 Int64,
          255 UInt8,
          65535 UInt16,
          4294967295 UInt32,
          18446744073709551615 UInt64
        FORMAT JSON
      )

      assert Pillar.query(conn, sql) ==
               {:ok,
                [
                  %{
                    "Int16" => -32_768,
                    "Int32" => -2_147_483_648,
                    "Int64" => -9_223_372_036_854_775_808,
                    "Int8" => -127,
                    "UInt16" => 65_535,
                    "UInt32" => 4_294_967_295,
                    "UInt64" => 18_446_744_073_709_551_615,
                    "UInt8" => 255
                  }
                ]}
    end

    test "Parentheses tests", %{conn: conn} do
      sql = "SELECT IF(0 == 1, NULL, 2) as number"

      assert Pillar.select(conn, sql) == {:ok, [%{"number" => 2}]}
    end

    test "Keyword tests", %{conn: conn} do
      %{"major" => major} = version(conn)

      if major >= 21 do
        sql_string_values = "SELECT map('foo', 'bar', 'baz', 'test') as test_map"
        sql_integer_values = "SELECT map('foo', 1, 'bar', 2) as test_map"
        sql_array_values = "SELECT map('foo', ['1', '2', '3'], 'bar', ['a', 'b']) as test_map"

        assert Pillar.select(conn, sql_string_values) ==
                 {:ok, [%{"test_map" => [baz: "test", foo: "bar"]}]}

        assert Pillar.select(conn, sql_integer_values) ==
                 {:ok, [%{"test_map" => [bar: 2, foo: 1]}]}

        assert Pillar.select(conn, sql_array_values) ==
                 {:ok, [%{"test_map" => [bar: ["a", "b"], foo: ["1", "2", "3"]]}]}
      else
        Logger.warn("Parentheses tests skip, becouse CH major version is lower than 21")
      end
    end
  end

  test "#query/2 - query numbers", %{conn: conn} do
    assert Pillar.query(conn, "SELECT * FROM system.numbers LIMIT 5") ==
             {:ok, "0\n1\n2\n3\n4\n"}
  end

  test "#query/2 - select numbers", %{conn: conn} do
    assert Pillar.select(conn, "SELECT * FROM system.numbers LIMIT 5") ==
             {:ok,
              [
                %{"number" => 0},
                %{"number" => 1},
                %{"number" => 2},
                %{"number" => 3},
                %{"number" => 4}
              ]}
  end

  test "#query/2 - max_query_size", %{conn: conn} do
    conn1 = %Connection{conn | max_query_size: 1}
    conn2 = %Connection{conn | max_query_size: -1}
    conn3 = %Connection{conn | max_query_size: 1024}

    assert {:error, %Pillar.HttpClient.Response{body: error1}} =
             Pillar.query(conn1, "SELECT * FROM system.numbers LIMIT 5")

    assert {:error, %Pillar.HttpClient.Response{body: error2}} =
             Pillar.query(conn2, "SELECT * FROM system.numbers LIMIT 5")

    assert {:ok, _data} = Pillar.query(conn3, "SELECT * FROM system.numbers LIMIT 5")

    assert error1 =~ ~r/Max query size exceeded/
    assert error2 =~ ~r/Unsigned type must not contain '-' symbol/
  end

  test "#query/3 - select numbers", %{conn: conn} do
    assert Pillar.select(conn, "SELECT * FROM system.numbers LIMIT {limit}", %{limit: 1}) ==
             {:ok,
              [
                %{"number" => 0}
              ]}
  end

  test "IP tests", %{conn: conn} do
    sql =
      "SELECT toIPv4('1.1.1.1') as ip4, toIPv6('2001:db8::8a2e:370:7334') as ip6, toIPv4('2.2.2.2') == toIPv4({ip}) as matches"

    assert {:ok, [%{"ip4" => "1.1.1.1", "ip6" => "2001:db8::8a2e:370:7334", "matches" => 1}]} =
             Pillar.select(conn, sql, %{ip: {2, 2, 2, 2}})
  end

  describe "#insert_to_table" do
    test "bad request with unexistable fields", %{conn: conn} do
      %{"major" => major, "minor" => minor} = version(conn)

      table_name = "to_table_inserts_with_fail_expected#{@timestamp}"

      create_table_sql = """
        CREATE TABLE IF NOT EXISTS #{table_name} (
          field0 Float64,
          field1 String,
          field2 UInt16,
          field3 Array(UInt16)
        ) ENGINE = Memory
      """

      assert {:ok, ""} = Pillar.query(conn, create_table_sql)

      assert {atom, result} =
               Pillar.insert_to_table(conn, table_name, %{
                 field0: 1.1,
                 field1: "Hello",
                 field2: 0,
                 field3: [1, 2, 3],
                 field4: "this field doesn't exists"
               })

      is_ok =
        cond do
          major >= 23 && atom == :ok && result == "" ->
            true

          major >= 22 && minor >= 6 && atom == :ok && result == "" ->
            true

          major <= 22 && minor < 6 && atom == :error &&
              inspect(result) =~ ~r/Unknown field found while parsing/ ->
            true

          # it's all other cases
          true ->
            false
        end

      assert is_ok == true
    end

    test "insert one record", %{conn: conn} do
      table_name = "to_table_inserts_#{@timestamp}"

      create_table_sql = """
        CREATE TABLE IF NOT EXISTS #{table_name} (
          field1 String,
          field2 UInt16,
          field3 Array(UInt16)
        ) ENGINE = Memory
      """

      assert {:ok, ""} = Pillar.query(conn, create_table_sql)

      assert {:ok, ""} =
               Pillar.insert_to_table(conn, table_name, %{
                 field1: "Hello",
                 field2: 0,
                 field3: [1, 2, 3]
               })

      assert {:ok, [%{"field1" => "Hello", "field2" => 0, "field3" => [1, 2, 3]}]} =
               Pillar.select(conn, "select * from #{table_name}")
    end

    test "insert one record 2", %{conn: conn} do
      table_name = "to_table_inserts2_#{@timestamp}"

      create_table_sql = """
        CREATE TABLE IF NOT EXISTS #{table_name} (
          field1 Float64,
          field2 UInt16,
          field3 Array(UInt16)
        ) ENGINE = Memory
      """

      assert {:ok, ""} = Pillar.query(conn, create_table_sql)

      assert {:ok, ""} =
               Pillar.insert_to_table(conn, table_name, %{
                 field1: 1.1e34,
                 field2: 0,
                 field3: [1, 2, 3]
               })

      assert {:ok, [%{"field1" => 1.1e34, "field2" => 0, "field3" => [1, 2, 3]}]} =
               Pillar.select(conn, "select * from #{table_name}")
    end

    test "insert one record with array of nullable type", %{conn: conn} do
      table_name = "to_table_inserts_array_of_nullable_#{@timestamp}"

      create_table_sql = """
        CREATE TABLE IF NOT EXISTS #{table_name} (
          field Array(Nullable(UInt16))
        ) ENGINE = Memory
      """

      assert {:ok, ""} = Pillar.query(conn, create_table_sql)

      assert {:ok, ""} =
               Pillar.insert_to_table(conn, table_name, %{
                 field: [nil, 2, 3]
               })

      assert {:ok, [%{"field" => [nil, 2, 3]}]} =
               Pillar.select(conn, "select * from #{table_name}")
    end

    test "select, that includes float with e", %{conn: conn} do
      sql = "SELECT {f} as f, {i} as i"

      assert {:ok, [%{"f" => 1.1e23, "i" => 13}]} == Pillar.select(conn, sql, %{f: 1.1e23, i: 13})
    end

    test "insert multiple records", %{conn: conn} do
      table_name = "to_table_inserts_multiple_#{@timestamp}"

      create_table_sql = """
        CREATE TABLE IF NOT EXISTS #{table_name} (
          field1 String,
          field2 UInt16,
          field3 Array(UInt16)
        ) ENGINE = Memory
      """

      assert {:ok, ""} = Pillar.query(conn, create_table_sql)

      record = %{
        "field1" => "Hello",
        "field2" => 0,
        "field3" => [1, 2, 3]
      }

      assert {:ok, ""} =
               Pillar.insert_to_table(conn, table_name, [record, record, record, record, record])

      assert {:ok, [^record, ^record, ^record, ^record, ^record]} =
               Pillar.select(conn, "select * from #{table_name}")
    end

    test "insert keyword as map", %{conn: conn} do
      %{"major" => major} = version(conn)

      if major >= 21 do
        table_name = "to_table_inserts_keyword_#{@timestamp}"

        create_table_sql = """
        CREATE TABLE IF NOT EXISTS #{table_name} (
            field4 Map(String, String)
          ) ENGINE = Memory
        """

        assert {:ok, ""} = Pillar.query(conn, create_table_sql)

        record = %{
          "field4" => [foo: "bar", baz: "bak"]
        }

        assert {:ok, ""} = Pillar.insert_to_table(conn, table_name, record)

        assert {:ok,
                [
                  %{"field4" => [{:baz, "bak"}, {:foo, "bar"}]}
                ]} = Pillar.select(conn, "select * from #{table_name}")
      else
        Logger.warn("insert keyword as map, because CH major version is lower than 21")
      end
    end

    test "insert keyword as boolean", %{conn: conn} do
      %{"major" => major, "minor" => minor} = version(conn)

      if major > 21 or (major >= 21 and minor >= 12) do
        table_name = "to_table_inserts_booleans_#{@timestamp}"

        create_table_sql = """
        CREATE TABLE IF NOT EXISTS #{table_name} (
            field5 boolean
          ) ENGINE = Memory
        """

        assert {:ok, ""} = Pillar.query(conn, create_table_sql)

        record = [%{"field5" => true}]

        assert {:ok, ""} = Pillar.insert_to_table(conn, table_name, record)

        assert {:ok,
                [
                  %{"field5" => true}
                ]} = Pillar.select(conn, "select * from #{table_name}")
      else
        Logger.warn("insert keyword as boolean, because CH major version is lower than 21")
      end
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
