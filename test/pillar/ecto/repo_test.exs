defmodule StockTrade do
  use Ecto.Schema

  @primary_key false
  schema "stock_trades" do
    field(:ticker, :string)
    field(:size, :integer)
    field(:price, :float)
    field(:time, :utc_datetime)
  end
end

defmodule Repo do
  use Ecto.Repo,
    adapter: Pillar.Ecto,
    loggers: [Ecto.LogEntry],
    otp_app: :pillar
end

defmodule Pillar.Ecto.RepoTest do
  alias Pillar.Connection
  use ExUnit.Case

  import Ecto.Query

  setup do
    defmodule PillarWorker do
      use Pillar,
        connection_strings: List.wrap(Application.get_env(:pillar, :connection_url)),
        name: __MODULE__,
        pool_size: 3
    end

    {:ok, _} = PillarWorker.start_link()

    create_table_sql = """
      CREATE TABLE stock_trades (
        ticker LowCardinality(String),
        price Float64,
        size UInt32,
        time DateTime
      ) ENGINE = MergeTree
      Order By(ticker, time)
    """

    insert_query_sql = """
      INSERT INTO stock_trades
        (ticker, price, size, time)
      VALUES
      ('SPY', 410.12, 10, '2023-04-01 16:04:55'),
      ('SPY', 410.11, 4, '2023-04-01 16:04:54'),
      ('SPY', 410.11, 7, '2023-04-01 16:04:54'),
      ('SPY', 410.11, 6, '2023-04-01 16:04:54'),
      ('JPM', 120.12, 1, '2023-04-01 16:04:53'),
      ('JPM', 121.32, 10, '2023-04-01 16:04:53'),
      ('JPM', 123.01, 45, '2023-04-01 16:04:52'),
      ('INTC', 29.59, 22, '2023-04-01 16:04:51')
    """

    assert PillarWorker.query("drop table if exists stock_trades") == {:ok, ""}
    assert PillarWorker.query(create_table_sql) == {:ok, ""}
    assert PillarWorker.query(insert_query_sql) == {:ok, ""}

    Repo.start_link()

    :ok
  end

  test "can select all rows" do
    trades = Repo.all(StockTrade)

    assert length(trades) == 7
  end

  test "can select a single row" do
    trade = Repo.one(from(st in StockTrade, limit: 1))

    refute is_nil(trade)
  end

  test "can group by ticker & count rows" do
    data =
      from(
        st in StockTrade,
        select: %{
          ticker: st.ticker,
          total: count(st.ticker),
          max_size: max(st.size),
          min_size: min(st.size)
        },
        group_by: st.ticker
      )
      |> Repo.all()
      |> IO.inspect()

    [
      %{max_size: 10, min_size: 4, ticker: "SPY", total: 4},
      %{max_size: 22, min_size: 22, ticker: "INTC", total: 1},
      %{max_size: 45, min_size: 1, ticker: "JPM", total: 3}
    ] = data
  end

  test "can filter" do
    dynamic_ticker = "AAPL"
    dynamic_size = 10

    res =
      from(st in StockTrade, where: st.ticker == ^dynamic_ticker and st.size >= ^dynamic_size)
      |> Repo.all()

    assert Enum.empty?(res)

    res = from(st in StockTrade, where: st.ticker == "INTC") |> Repo.all()
    refute Enum.empty?(res)

    res = from(st in StockTrade, where: st.ticker != "AAPL") |> Repo.all()
    refute Enum.empty?(res)

    res =
      from(st in StockTrade, where: st.price >= 400, select: st.ticker)
      |> Repo.all()
      |> Enum.uniq()

    assert res == ["SPY"]
  end
end
