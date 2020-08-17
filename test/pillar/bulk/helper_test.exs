defmodule Pillar.Bulk.HelperTest do
  use ExUnit.Case
  alias Pillar.Bulk.Helper

  test "#generate_bulk_insert_query/3" do
    values = [
      %{field_1: 1, field_2: 2, field_3: 3},
      %{field_1: 1, field_2: 2, field_3: 4},
      %{field_1: 1},
      %{field_2: 2},
      %{field_3: 4},
      %{}
    ]

    columns = ["field_1", "field_2", "field_3"]
    table_name = "example"

    assert {"INSERT INTO example (field_1, field_2, field_3) FORMAT Values ({field_1_0}, {field_2_0}, {field_3_0}), ({field_1_1}, {field_2_1}, {field_3_1}), ({field_1_2}, {field_2_2}, {field_3_2}), ({field_1_3}, {field_2_3}, {field_3_3}), ({field_1_4}, {field_2_4}, {field_3_4}), ({field_1_5}, {field_2_5}, {field_3_5})",
            %{
              "field_1_0" => 1,
              "field_1_1" => 1,
              "field_1_2" => 1,
              "field_1_3" => nil,
              "field_1_4" => nil,
              "field_1_5" => nil,
              "field_2_0" => 2,
              "field_2_1" => 2,
              "field_2_2" => nil,
              "field_2_3" => 2,
              "field_2_4" => nil,
              "field_2_5" => nil,
              "field_3_0" => 3,
              "field_3_1" => 4,
              "field_3_2" => nil,
              "field_3_3" => nil,
              "field_3_4" => 4,
              "field_3_5" => nil
            }} ==
             Helper.generate_bulk_insert_query(table_name, columns, values)
  end
end
