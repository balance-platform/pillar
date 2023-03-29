defmodule Pillar.QueryBuilderTest do
  use ExUnit.Case
  alias Pillar.QueryBuilder

  test "#query/2 - pastes params (atom keys)" do
    sql = "SELECT * FROM table WHERE lastname = {lastname} AND birthdate = {birthdate}"

    params = %{
      lastname: "Smith",
      birthdate: ~D[1970-03-13]
    }

    assert QueryBuilder.query(sql, params) ==
             "SELECT * FROM table WHERE lastname = 'Smith' AND birthdate = '1970-03-13'"
  end

  test "#query/2 - pastes params (string keys)" do
    sql = "SELECT * FROM table WHERE lastname = {lastname} AND birthdate = {birthdate}"

    params = %{
      "lastname" => "Smith",
      "birthdate" => ~D[1970-03-13]
    }

    assert QueryBuilder.query(sql, params) ==
             "SELECT * FROM table WHERE lastname = 'Smith' AND birthdate = '1970-03-13'"
  end

  test "#query/2 - pastes boolean params" do
    sql = "SELECT * FROM table WHERE active = {active} and deleted = {deleted}"

    params = %{
      active: true,
      deleted: false
    }

    assert QueryBuilder.query(sql, params) ==
             "SELECT * FROM table WHERE active = 1 and deleted = 0"
  end

  describe "insert_to_table/2" do
    test "#insert_to_table/2 - map argument" do
      table_name = "example"
      record = %{field_1: 1}

      assert ["INSERT INTO", "example", "FORMAT JSONEachRow", "{\"field_1\":\"1\"}"] ==
               String.split(QueryBuilder.insert_to_table(table_name, record), "\n")
    end

    test "#insert_to_table/2 - list argument" do
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
               String.split(QueryBuilder.insert_to_table(table_name, values, nil), "\n")
    end
  end
end
