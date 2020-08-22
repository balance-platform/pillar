defmodule Pillar.QueryBuilderTest do
  use ExUnit.Case
  alias Pillar.QueryBuilder
  alias Pillar.TypeConvert.ToClickhouse
  alias Pillar.TypeConvert.ToClickhouseJson

  describe "ToClickhouse convert" do
    test "#build/3 - pastes params (atom keys)" do
      sql = "SELECT * FROM table WHERE lastname = {lastname} AND birthdate = {birthdate}"

      params = %{
        lastname: "Smith",
        birthdate: ~D[1970-03-13]
      }

      assert QueryBuilder.build(sql, params, ToClickhouse) ==
               "SELECT * FROM table WHERE lastname = 'Smith' AND birthdate = '1970-03-13'"
    end

    test "#build/3 - pastes params (string keys)" do
      sql = "SELECT * FROM table WHERE lastname = {lastname} AND birthdate = {birthdate}"

      params = %{
        "lastname" => "Smith",
        "birthdate" => ~D[1970-03-13]
      }

      assert QueryBuilder.build(sql, params, ToClickhouse) ==
               "SELECT * FROM table WHERE lastname = 'Smith' AND birthdate = '1970-03-13'"
    end
  end

  describe "ToClickhouseJSON convert" do
    test "#build/3 - pastes converted jsons" do
      sql = "SELECT {r1}"

      params = %{
        r1: %{
          "lastname" => "Smith",
          "birthdate" => ~D[1970-03-13],
          "posts_jsons" => [
            Jason.encode!(%{title: "Post1"}),
            Jason.encode!(%{title: "Post2"})
          ]
        }
      }

      assert QueryBuilder.build(sql, params, ToClickhouseJson) ==
               "SELECT * FROM table WHERE lastname = 'Smith' AND birthdate = '1970-03-13'"
    end
  end
end
