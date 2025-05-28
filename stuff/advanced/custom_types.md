# Custom Type Conversions

Pillar automatically handles conversions between Elixir data types and ClickHouse data types. However, you can extend or customize this behavior for advanced use cases.

## Default Type Conversions

Pillar handles these type conversions out of the box:

| Elixir Type | ClickHouse Type |
|-------------|----------------|
| Integer | Int8, Int16, Int32, Int64, UInt8, UInt16, UInt32, UInt64 |
| Float | Float32, Float64, Decimal |
| String | String, FixedString, Enum |
| Boolean | UInt8 (0/1) |
| DateTime | DateTime, DateTime64 |
| Date | Date, Date32 |
| Map | Object, JSON |
| List | Array |
| Tuple | Tuple |
| UUID | UUID |

## Custom Type Implementations

### Converting Custom Structs to ClickHouse

You can implement the `Pillar.TypeConvert.ToClickHouse` protocol for your custom structs:

```elixir
defmodule MyApp.User do
  defstruct [:id, :name, :email, :metadata, :inserted_at]
end

defimpl Pillar.TypeConvert.ToClickHouse, for: MyApp.User do
  def convert(user) do
    %{
      id: user.id,
      name: user.name,
      email: user.email,
      metadata: Jason.encode!(user.metadata),
      created_at: DateTime.to_iso8601(user.inserted_at)
    }
  end
end
```

Now you can directly insert `User` structs:

```elixir
user = %MyApp.User{
  id: 123,
  name: "John Doe",
  email: "john@example.com",
  metadata: %{preferences: %{theme: "dark"}},
  inserted_at: DateTime.utc_now()
}

Pillar.insert_to_table(conn, "users", user)
```

### Custom JSON Conversion

For specialized JSON formatting:

```elixir
defimpl Pillar.TypeConvert.ToClickHouseJson, for: MyApp.User do
  def convert(user) do
    %{
      "user_id" => user.id,
      "full_name" => user.name,
      "contact" => %{
        "email" => user.email
      },
      "preferences" => user.metadata,
      "registration_date" => DateTime.to_unix(user.inserted_at)
    }
  end
end
```

### Custom Types for Query Parameters

You can also use custom types in query parameters:

```elixir
defmodule MyApp.GeoPoint do
  defstruct [:latitude, :longitude]
  
  def new(lat, lon) do
    %__MODULE__{latitude: lat, longitude: lon}
  end
end

defimpl Pillar.TypeConvert.ToClickHouse, for: MyApp.GeoPoint do
  def convert(point) do
    "#{point.latitude},#{point.longitude}"
  end
end
```

Usage:

```elixir
point = MyApp.GeoPoint.new(52.5200, 13.4050)

Pillar.query(
  conn,
  "SELECT * FROM locations WHERE geoDistance(point, {location}) < 1000",
  %{location: point}
)
```

## Working with ClickHouse Arrays

To handle ClickHouse arrays efficiently:

```elixir
defmodule MyApp.TaggedItem do
  defstruct [:id, :name, :tags]
end

defimpl Pillar.TypeConvert.ToClickHouse, for: MyApp.TaggedItem do
  def convert(item) do
    %{
      id: item.id,
      name: item.name,
      tags: Enum.join(item.tags, ",")  # Convert Elixir list to ClickHouse Array format
    }
  end
end
```

Querying arrays:

```elixir
Pillar.query(
  conn,
  "SELECT * FROM items WHERE hasAny(tags, {search_tags})",
  %{search_tags: ["important", "featured"]}
)
```

## DateTime Handling

ClickHouse has specific requirements for DateTime values. You can customize the conversion:

```elixir
defmodule MyApp.TimeRange do
  defstruct [:start_time, :end_time]
end

defimpl Pillar.TypeConvert.ToClickHouse, for: MyApp.TimeRange do
  def convert(range) do
    %{
      start_time: DateTime.to_iso8601(range.start_time),
      end_time: DateTime.to_iso8601(range.end_time)
    }
  end
end
```

## Extending Existing Types

You can also extend existing implementations:

```elixir
defimpl Pillar.TypeConvert.ToClickHouse, for: DateTime do
  # Override the default implementation
  def convert(datetime) do
    # Format with microsecond precision
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M:%S.%6f")
  end
end
```

## Custom Decoding of ClickHouse Values

To customize how ClickHouse values are converted to Elixir:

```elixir
defmodule MyApp.ClickHouseJson do
  @behaviour Pillar.TypeConvert.ToElixir

  def convert("DateTime", value) do
    # Custom DateTime parsing
    {:ok, datetime, _} = DateTime.from_iso8601(value <> "Z")
    datetime
  end
  
  def convert("Array(String)", value) do
    # Custom array parsing
    String.split(value, ",") |> Enum.map(&String.trim/1)
  end
  
  # Fall back to default implementation for other types
  def convert(type, value) do
    Pillar.TypeConvert.ToElixir.convert(type, value)
  end
end

# Configure Pillar to use your custom converter
config :pillar, :type_converter_to_elixir, MyApp.ClickHouseJson
```

## Best Practices

1. **Keep conversions pure**: Avoid side effects in conversion functions
2. **Handle errors gracefully**: Consider what happens with invalid data
3. **Respect ClickHouse types**: Ensure your conversions match the expected format
4. **Test conversions**: Verify both directions (Elixir to ClickHouse and back)
5. **Consider performance**: Conversions run for every record, so keep them efficient

