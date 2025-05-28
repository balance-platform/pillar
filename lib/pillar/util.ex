defmodule Pillar.Util do
  @moduledoc false
  def has_input_format_json_read_numbers_as_strings?(%Version{} = version) do
    Version.compare(version, "23.0.0") != :lt
  end

  def needs_decimal_zero_for_integers_in_json?(%Version{} = version) do
    Version.compare(version, "25.0.0") != :lt
  end
end
