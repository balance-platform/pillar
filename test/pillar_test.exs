defmodule PillarTest do
  use ExUnit.Case
  doctest Pillar
  alias Pillar.Connection

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
      {:ok, pid} = PillarWorker.start_link()
      {:ok, %{pid: pid}}
    end

    test "#query - without passing connection", %{pid: pid} do
      assert Process.alive?(pid) == true
      assert PillarWorker.query("SELECT 1") == {:ok, [%{"1" => 1}]}
    end

    test "#query - timeout tests" do
      assert PillarWorker.query("SELECT now()", %{}, %{timeout: 0}) ==
               {:error, %Pillar.HttpClient.TransportError{reason: :timeout}}
    end

    test "#async_query", %{pid: pid} do
      assert Process.alive?(pid) == true
      assert PillarWorker.async_query("SELECT 1") == :ok
    end
  end

  describe "data types tests" do
    test "UUID test", %{conn: conn} do
      assert {:ok, [%{"uuid" => uuid}]} = Pillar.query(conn, "SELECT generateUUIDv4() as uuid")

      assert String.valid?(uuid) && String.length(uuid) == 36
    end

    test "Array test", %{conn: conn} do
      assert {:ok, [%{"array" => [1, 2, 3]}]} = Pillar.query(conn, "SELECT [1, 2, 3] as array")

      assert {:ok, [%{"array" => ["1", "2", "3"]}]} =
               Pillar.query(conn, "SELECT ['1', '2', '3'] as array")

      assert {:ok, [%{"array" => [%DateTime{}, %DateTime{}, nil]}]} =
               Pillar.query(conn, "SELECT [now(), now(), NULL] as array")
    end

    test "String test", %{conn: conn} do
      sql = "SELECT 'ИВАН МИХАЛЫЧ' name"

      assert {:ok, [%{"name" => "ИВАН МИХАЛЫЧ"}]} = Pillar.query(conn, sql)
    end

    test "FixedString test", %{conn: conn} do
      create_table_sql = """
        CREATE TABLE IF NOT EXISTS fixed_string_table (field FixedString(10)) ENGINE = Memory
      """

      insert_query_sql = """
        INSERT INTO fixed_string_table SELECT '0123456789'
      """

      assert {:ok, ""} = Pillar.query(conn, create_table_sql)
      assert {:ok, ""} = Pillar.query(conn, insert_query_sql)

      assert {:ok, [%{"field" => "0123456789"}]} =
               Pillar.query(conn, "SELECT * FROM fixed_string_table LIMIT 1")
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
               Pillar.query(conn, "SELECT * FROM enum8_table LIMIT 1")
    end

    test "Date test", %{conn: conn} do
      sql = "SELECT today()"

      assert {:ok, [%{"today()" => %Date{}}]} = Pillar.query(conn, sql)
    end

    test "DateTime test", %{conn: conn} do
      sql = "SELECT now()"

      assert {:ok, [%{"now()" => %DateTime{}}]} = Pillar.query(conn, sql)
    end

    test "Float tests", %{conn: conn} do
      sql = ~s(
        SELECT 
          -127.0 Float32,
          -92233720368.31 Float64
      )

      assert Pillar.query(conn, sql) ==
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
  end

  test "#query/2 - select numbers", %{conn: conn} do
    assert Pillar.query(conn, "SELECT * FROM system.numbers LIMIT 5") ==
             {:ok,
              [
                %{"number" => 0},
                %{"number" => 1},
                %{"number" => 2},
                %{"number" => 3},
                %{"number" => 4}
              ]}
  end

  test "#query/3 - select numbers", %{conn: conn} do
    assert Pillar.query(conn, "SELECT * FROM system.numbers LIMIT {limit}", %{limit: 1}) ==
             {:ok,
              [
                %{"number" => 0}
              ]}
  end
end
