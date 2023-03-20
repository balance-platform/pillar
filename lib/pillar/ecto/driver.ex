defmodule Pillar.Ecto.Driver do
  alias Pillar.Ecto.Query

  def start_link(opts \\ []) do
    DBConnection.start_link(
      Pillar.Ecto.ConnMod,
      opts |> Keyword.put(:show_sensitive_data_on_connection_error, true)
    )
  end

  def child_spec(opts) do
    DBConnection.child_spec(Pillar.Ecto.ConnMod, opts)
  end

  def query(conn, statement, params \\ [], opts \\ []) do
    DBConnection.prepare_execute(conn, %Query{name: "", statement: statement}, params, opts)
  end

  def query!(conn, statement, params \\ [], opts \\ []) do
    DBConnection.prepare_execute!(conn, %Query{name: "", statement: statement}, params, opts)
  end
end
