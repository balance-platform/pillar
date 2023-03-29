defmodule Pillar.Util do
  def has_input_format_json_read_numbers_as_strings?(%Version{} = version) do
    cond do
      is_nil(version) -> false
      Version.compare(version, "23.0.0") != :lt -> true
      :else -> false
    end
  end
end
