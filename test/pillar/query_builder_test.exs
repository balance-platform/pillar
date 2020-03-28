defmodule Pillar.QueryBuilderTest do
  use ExUnit.Case
  alias Pillar.QueryBuilder

  test "#build/2 - pastes params (atom keys)" do
    sql = "SELECT * FROM table WHERE lastname = {lastname} AND birthdate = {birthdate}"

    params = %{
      lastname: "Smith",
      birthdate: ~D[1970-03-13]
    }

    assert QueryBuilder.build(sql, params) ==
             "SELECT * FROM table WHERE lastname = 'Smith' AND birthdate = '1970-03-13'"
  end

  test "#build/2 - pastes params (string keys)" do
    sql = "SELECT * FROM table WHERE lastname = {lastname} AND birthdate = {birthdate}"

    params = %{
      "lastname" => "Smith",
      "birthdate" => ~D[1970-03-13]
    }

    assert QueryBuilder.build(sql, params) ==
             "SELECT * FROM table WHERE lastname = 'Smith' AND birthdate = '1970-03-13'"
  end
end
