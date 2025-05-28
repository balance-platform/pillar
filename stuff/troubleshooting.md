# Troubleshooting

This guide covers common issues you may encounter when using Pillar with ClickHouse, along with solutions and performance optimization tips.

## Connection Issues

### Failed to Connect to ClickHouse Server

**Problem:** Cannot establish a connection to the ClickHouse server.

**Symptoms:**
```
{:error, %Pillar.HttpClient.TransportError{reason: :econnrefused}}
```

**Solutions:**

1. **Check server availability:**
   ```bash
   curl http://your-clickhouse-host:8123/ping
   ```
   If this doesn't return "OK", the server might be down or unreachable.

2. **Verify credentials:**
   Ensure your username and password are correct in the connection string.

3. **Check network connectivity:**
   - Verify your application can reach the ClickHouse host
   - Check for firewall rules blocking port 8123
   - Ensure the ClickHouse server is configured to accept external connections

4. **Inspect server logs:**
   Look at ClickHouse server logs for any errors related to connections or authentication.

### Connection Timeout

**Problem:** Connection attempts to ClickHouse time out.

**Symptoms:**
```
{:error, %Pillar.HttpClient.TransportError{reason: :timeout}}
```

**Solutions:**

1. **Increase timeout value:**
   ```elixir
   conn = Pillar.Connection.new(
     "http://user:password@localhost:8123/database",
     %{timeout: 30_000} # 30 seconds
   )
   ```

2. **Check server load:**
   High server load can cause timeouts. Check ClickHouse's system metrics:
   ```sql
   SELECT * FROM system.metrics
   ```

3. **Network latency:**
   Consider using a server in the same region/datacenter as your application to reduce latency.

## Query Execution Issues

### Invalid Query Syntax

**Problem:** SQL syntax errors in queries.

**Symptoms:**
```
{:error, "Code: 62. DB::Exception: Syntax error: failed at position 10 (...)"
```

**Solutions:**

1. **Validate SQL syntax:**
   Test your query directly against ClickHouse using the HTTP interface or clickhouse-client.

2. **Check parameter placeholders:**
   Ensure all parameter placeholders in the query have corresponding values in the params map:
   ```elixir
   # Correct
   Pillar.query(conn, "SELECT * FROM users WHERE id = {id}", %{id: 123})
   
   # Incorrect - missing parameter
   Pillar.query(conn, "SELECT * FROM users WHERE id = {id}", %{})
   ```

3. **ClickHouse SQL specifics:**
   Remember that ClickHouse SQL dialect has some differences from standard SQL.

### Out of Memory Errors

**Problem:** Query fails due to insufficient memory.

**Symptoms:**
```
{:error, "Code: 241. DB::Exception: Memory limit (for query) exceeded: ..."
```

**Solutions:**

1. **Limit query resources:**
   ```elixir
   Pillar.query(conn, "SELECT * FROM large_table", %{}, %{
     max_memory_usage: 10000000000, # 10GB
     max_bytes_before_external_sort: 5000000000 # 5GB
   })
   ```

2. **Add query limits:**
   ```elixir
   Pillar.select(conn, "SELECT * FROM huge_table LIMIT 1000", %{})
   ```

3. **Use sampling:**
   ```elixir
   Pillar.select(conn, "SELECT * FROM huge_table SAMPLE 0.1", %{})
   ```

4. **Optimize schema:**
   Ensure your tables are using appropriate engines and sorting keys.

## Data Insertion Issues

### Bulk Insert Failures

**Problem:** Bulk insert operations fail with data type errors.

**Symptoms:**
```
{:error, "Code: 53. DB::Exception: Cannot parse input: expected )..."
```

**Solutions:**

1. **Validate data types:**
   Ensure all values match the expected column types in your table.

2. **Check schema compatibility:**
   ```elixir
   # Get table structure
   {:ok, structure} = Pillar.query(conn, "DESCRIBE TABLE your_table")
   ```

3. **Handle NULL values appropriately:**
   ClickHouse has strict NULL handling. Use default values where appropriate.

4. **Break into smaller batches:**
   If inserting large amounts of data, break it into smaller batches:
   ```elixir
   Enum.chunk_every(records, 1000)
   |> Enum.each(fn batch ->
     Pillar.insert_to_table(conn, "your_table", batch)
   end)
   ```

### Async Insert Issues

**Problem:** Async inserts silently fail without error reporting.

**Solutions:**

1. **Implement logging:**
   While async operations don't return errors, you can log them in your application:
   ```elixir
   # Start process monitoring ClickHouse logs
   def monitor_clickhouse_errors do
     # Poll error log table periodically
     schedule_check()
     
     # ...
   end
   ```

2. **Use buffered inserts with error callbacks:**
   ```elixir
   defmodule MyApp.InsertBuffer do
     use Pillar.BulkInsertBuffer,
       pool: MyApp.ClickHouse,
       table_name: "events",
       on_errors: &__MODULE__.handle_errors/2
       
     def handle_errors(error, records) do
       Logger.error("Failed insert: #{inspect(error)}")
       # Save failed records for retry
     end
   end
   ```

## Pool Connection Issues

### Pool Timeout

**Problem:** Timeout when trying to get a connection from the pool.

**Symptoms:**
```
{:error, :timeout}
```

**Solutions:**

1. **Increase pool size:**
   ```elixir
   defmodule MyApp.ClickHouse do
     use Pillar,
       connection_strings: ["http://..."],
       pool_size: 30  # Increase from default 10
   end
   ```

2. **Increase pool timeout:**
   ```elixir
   defmodule MyApp.ClickHouse do
     use Pillar,
       connection_strings: ["http://..."],
       pool_timeout: 10_000  # 10 seconds
   end
   ```

3. **Check for connection leaks:**
   Ensure all operations properly return connections to the pool.

4. **Monitor pool utilization:**
   ```elixir
   # Check current pool status
   :poolboy.status(MyApp.ClickHouse.name())
   ```

## Schema and Migration Issues

### Migration Failures

**Problem:** ClickHouse migrations fail to apply.

**Solutions:**

1. **Check migration syntax:**
   Validate SQL statements directly in ClickHouse.

2. **Use transaction-like behavior:**
   ClickHouse doesn't support transactions, but you can implement rollback functions:
   ```elixir
   defmodule Pillar.Migrations.CreateComplexSchema do
     def up do
       [
         "CREATE TABLE table_1 (...)",
         "CREATE TABLE table_2 (...)"
       ]
     end
     
     def down do
       [
         "DROP TABLE table_2",
         "DROP TABLE table_1"
       ]
     end
   end
   ```

3. **Inspect migration state:**
   Query the `pillar_migrations` table to see which migrations were applied:
   ```elixir
   {:ok, applied} = Pillar.select(conn, "SELECT * FROM pillar_migrations")
   ```

## Type Conversion Issues

### DateTime Conversion Problems

**Problem:** DateTime values are not correctly stored or retrieved.

**Solutions:**

1. **Ensure timezone configuration:**
   ```elixir
   # In config.exs
   config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase
   ```

2. **Use explicit formatting:**
   ```elixir
   # When inserting
   datetime_str = DateTime.utc_now() |> DateTime.to_iso8601()
   Pillar.query(conn, "INSERT INTO events VALUES ({timestamp})", %{timestamp: datetime_str})
   ```

3. **Customize DateTime conversion:**
   ```elixir
   defimpl Pillar.TypeConvert.ToClickHouse, for: DateTime do
     def convert(datetime) do
       Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S")
     end
   end
   ```

### JSON Data Issues

**Problem:** Complex JSON structures don't serialize correctly.

**Solutions:**

1. **Pre-serialize JSON:**
   ```elixir
   json_string = Jason.encode!(complex_map)
   Pillar.query(conn, "INSERT INTO logs VALUES ({data})", %{data: json_string})
   ```

2. **Use ClickHouse JSON functions:**
   ```elixir
   Pillar.select(conn, "SELECT JSONExtractString(data, 'key') FROM logs")
   ```

## Performance Optimization

### Query Performance

1. **Use proper table engines:**
   - MergeTree family for most analytical workloads
   - ReplacingMergeTree for data that needs to be updated
   - SummingMergeTree for pre-aggregated data

2. **Optimize ORDER BY clause:**
   - Include columns frequently used in WHERE clauses
   - Put high-cardinality columns first

3. **Use materialized views:**
   ```sql
   CREATE MATERIALIZED VIEW user_stats
   ENGINE = SummingMergeTree()
   ORDER BY (date, user_id)
   AS SELECT
     toDate(timestamp) AS date,
     user_id,
     count() AS event_count
   FROM events
   GROUP BY date, user_id
   ```

4. **Add query hints:**
   ```elixir
   Pillar.query(conn, """
   SELECT * FROM large_table
   WHERE date = {date}
   SETTINGS max_threads = 8, max_memory_usage = 20000000000
   """, %{date: Date.utc_today()})
   ```

### Insertion Performance

1. **Batch inserts appropriately:**
   - Too small: Network overhead
   - Too large: Memory pressure
   - Typical sweet spot: 1,000-10,000 records per batch

2. **Use asynchronous inserts for non-critical data:**
   ```elixir
   MyApp.ClickHouse.async_insert_to_table("logs", records)
   ```

3. **Optimize for bulk loads:**
   ```elixir
   Pillar.query(conn, """
   INSERT INTO table 
   SELECT * FROM input('format CSV')
   """, %{}, %{input_format_allow_errors_num: 10})
   ```

4. **Consider data locality:**
   For distributed ClickHouse clusters, insert to the appropriate shard.

### Connection Optimization

1. **Pool sizing formula:**
   ```
   pool_size = min(
     max_expected_concurrent_queries,
     (available_memory / avg_query_memory_usage)
   )
   ```

2. **Reuse connections:**
   Avoid creating new connections for every request.

3. **Load balance with multiple servers:**
   ```elixir
   defmodule MyApp.ClickHouse do
     use Pillar,
       connection_strings: [
         "http://clickhouse-1:8123/db",
         "http://clickhouse-2:8123/db",
         "http://clickhouse-3:8123/db"
       ]
   end
   ```

4. **Use HTTP keep-alive:**
   Pillar's Tesla Mint adapter uses HTTP keep-alive by default, reducing connection overhead.

## Debugging Tips

### Enable Verbose Logging

```elixir
# In config/config.exs
config :logger, level: :debug

# In your application
Logger.configure(level: :debug)
```

### Inspect Queries with EXPLAIN

```elixir
Pillar.query(conn, "EXPLAIN SELECT * FROM large_table WHERE date = {date}", %{date: "2023-01-01"})
```

### Profile Queries

```elixir
Pillar.query(conn, "EXPLAIN ANALYZE SELECT * FROM large_table WHERE date = {date}", %{date: "2023-01-01"})
```

### Monitor System Tables

```elixir
# Check currently running queries
Pillar.select(conn, "SELECT * FROM system.processes")

# Check query log for slow queries
Pillar.select(conn, """
  SELECT 
    query_duration_ms,
    query 
  FROM system.query_log 
  WHERE type = 'QueryFinish' 
  ORDER BY query_duration_ms DESC 
  LIMIT 10
""")
```

### Server-Side Logging

Increase ClickHouse server log verbosity if needed:

```xml
<!-- In config.xml -->
<logger>
    <level>trace</level>
</logger>
```

## Common Error Codes

| Code | Description | Common Causes |
|------|-------------|--------------|
| 53   | Cannot parse input | Data type mismatch, invalid format |
| 60   | Invalid query | Syntax error, invalid table name |
| 62   | Syntax error | Malformed SQL |
| 81   | Database not found | Wrong database name, incorrect URL |
| 149  | Tables differ in structure | Schema mismatch in INSERT |
| 192  | Unknown table | Table doesn't exist |
| 241  | Memory limit exceeded | Query requires too much memory |
| 252  | Required server restart | DDL operation needs server restart |

## Additional Resources

- [ClickHouse Documentation](https://clickhouse.tech/docs/en/)
- [ClickHouse SQL Reference](https://clickhouse.tech/docs/en/sql-reference/)
- [System Tables Reference](https://clickhouse.tech/docs/en/operations/system-tables/)
- [Troubleshooting Performance Issues](https://clickhouse.tech/docs/en/operations/troubleshooting/)

