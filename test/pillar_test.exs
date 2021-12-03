defmodule PillarTest do
  use ExUnit.Case
  doctest Pillar
  alias Pillar.Connection

  @timestamp DateTime.to_unix(DateTime.utc_now())

  setup do
    connection_url = Application.get_env(:pillar, :connection_url)
    connection = Connection.new(connection_url)

    {:ok, %{conn: connection}}
  end

  describe "GenServer tests" do
    defmodule PillarWorker do
      use Pillar,
        connection_strings: List.wrap(Application.get_env(:pillar, :connection_url)),
        name: __MODULE__,
        pool_size: 3
    end

    setup do
      PillarWorker.start_link()
      :ok
    end

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

      assert {:error, result} =
               Pillar.insert_to_table(conn, table_name, %{
                 field0: 1.1,
                 field1: "Hello",
                 field2: 0,
                 field3: [1, 2, 3],
                 field4: "this field doesn't exists"
               })

      assert inspect(result) =~ ~r/Unknown field found while parsing/
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
  end
end
