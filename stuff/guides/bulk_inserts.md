# Bulk Insert Strategies

ClickHouse excels at processing large volumes of data, and Pillar provides several strategies for efficiently inserting data in bulk.

## Why Bulk Inserts?

Bulk inserts offer several advantages:

- **Performance**: Much faster than individual inserts
- **Network Efficiency**: Fewer round trips to the server
- **Resource Utilization**: Reduced overhead for both client and server
- **Scalability**: Better handling of high-volume data streams

## Available Strategies

Pillar offers three main approaches for bulk inserts:

1. **Direct Batch Insert**: Insert multiple records in a single query
2. **Buffered Inserts**: Collect records and insert them periodically
3. **Async Inserts**: Non-blocking fire-and-forget operations

## Direct Batch Insert

The simplest approach is to batch multiple records into a single insert operation:

```elixir
# Create a list of records
records = [
  %{id: 1, name: "Alice", score: 85},
  %{id: 2, name: "Bob", score: 92},
  %{id: 3, name: "Charlie", score: 78},
  # ... potentially hundreds or thousands of records
]

# Insert them all in a single operation
{:ok, _} = Pillar.insert_to_table(conn, "students", records)
```

This approach is ideal when:
- You already have a complete batch of records
- You need to ensure all records are inserted successfully
- You want to handle any errors that might occur

## Buffered Inserts with BulkInsertBuffer

For streaming data or high-frequency inserts, Pillar provides the `BulkInsertBuffer` module:

```elixir
defmodule MyApp.EventBuffer do
  use Pillar.BulkInsertBuffer,
    # Reference to your Pillar connection pool
    pool: MyApp.ClickHouse,
    
    # Target table for inserts
    table_name: "events",
    
    # How often to flush buffered records (seconds)
    interval_between_inserts_in_seconds: 5,
    
    # Maximum records to buffer before forcing a flush
    max_buffer_size: 5000,
    
    # Optional error handler
    on_errors: &__MODULE__.handle_errors/2

  def handle_errors(error_result, failed_records) do
    # Log the error
    Logger.error("Failed to insert records: #{inspect(error_result)}")
    
    # Save failed records for later processing
    timestamp = DateTime.utc_now() |> DateTime.to_string() |> String.replace(":", "-")
    filepath = "failed_inserts/#{timestamp}.json"
    
    File.mkdir_p!("failed_inserts")
    File.write!(filepath, Jason.encode!(failed_records))
  end
end
```

Usage:

```elixir
# Start the buffer process in your supervision tree
children = [
  # ...
  MyApp.EventBuffer
]

# Insert records - they will be buffered and inserted periodically
:ok = MyApp.EventBuffer.insert(%{
  user_id: 123,
  event_type: "page_view",
  url: "/products",
  timestamp: DateTime.utc_now()
})
```

The buffer will:
1. Collect records in memory
2. Insert them as a batch every `interval_between_inserts_in_seconds` seconds
3. Force a flush if the buffer reaches `max_buffer_size` records
4. Call the error handler if insertions fail

This approach is ideal for:
- High-frequency event tracking
- Metrics collection
- Log aggregation
- Any scenario with many small records

## Asynchronous Inserts

For non-critical inserts where you don't need confirmation:

```elixir
# Using a connection pool
MyApp.ClickHouse.async_insert(
  "INSERT INTO logs (event, timestamp) VALUES ({event}, {timestamp})",
  %{event: "page_view", timestamp: DateTime.utc_now()}
)

# Or with insert_to_table
MyApp.ClickHouse.async_insert_to_table(
  "logs",
  %{event: "page_view", timestamp: DateTime.utc_now()}
)
```

Async inserts:
- Return immediately without waiting for a response
- Don't provide error handling
- Reduce backpressure in high-volume scenarios
- Are only available when using a connection pool

## Choosing the Right Strategy

| Strategy | Pros | Cons | Best For |
|----------|------|------|----------|
| Direct Batch | Simple, reliable | Blocking, requires accumulating records | Scheduled data loads, transactions |
| Buffered | Efficient for streams, error handling | Memory usage, potential data loss on crash | Event tracking, metrics, logging |
| Async | Non-blocking, minimal overhead | No error handling or confirmation | Non-critical data, monitoring data |

## Performance Optimization Tips

1. **Batch Size**: Experiment to find the optimal batch size (typically 1,000-10,000 records)
2. **Buffer Interval**: Balance between latency and efficiency (5-30 seconds is common)
3. **Schema Design**: Ensure tables are optimized for insert performance
4. **Data Types**: Use appropriate data types and avoid excessive string conversion
5. **Compression**: Consider using compressed formats for very large inserts
6. **Monitoring**: Watch memory usage and server load during bulk operations

## Example: Handling Large CSV Import

```elixir
defmodule MyApp.CsvImporter do
  def import_file(filename, chunk_size \\ 5000) do
    filename
    |> File.stream!()
    |> CSV.decode(headers: true)
    |> Stream.chunk_every(chunk_size)
    |> Stream.each(fn chunk ->
      records = Enum.map(chunk, &transform_record/1)
      {:ok, _} = MyApp.ClickHouse.insert_to_table("imported_data", records)
      IO.puts("Imported #{length(records)} records")
    end)
    |> Stream.run()
  end
  
  defp transform_record({:ok, map}) do
    # Transform CSV row into appropriate format for ClickHouse
    %{
      id: String.to_integer(map["id"]),
      name: map["name"],
      value: String.to_float(map["value"]),
      timestamp: parse_timestamp(map["timestamp"])
    }
  end
  
  defp parse_timestamp(timestamp_string) do
    # Parse timestamp from string
    {:ok, datetime, _} = DateTime.from_iso8601(timestamp_string)
    datetime
  end
end
```

Usage:

```elixir
MyApp.CsvImporter.import_file("large_dataset.csv")
```

