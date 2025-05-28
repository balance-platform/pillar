# HTTP Adapters

Pillar supports multiple HTTP adapters for communicating with ClickHouse servers. This allows you to choose the best implementation for your specific requirements or environment.

## Available Adapters

Pillar comes with two built-in HTTP adapters:

1. **Tesla Mint Adapter** (default) - Uses [Tesla](https://github.com/teamon/tesla) with the [Mint](https://github.com/elixir-mint/mint) HTTP client
2. **Httpc Adapter** - Uses Erlang's built-in `:httpc` module

## Adapter Architecture

Each adapter implements the `Pillar.HttpClient.Adapter` behaviour, which requires a `post/3` function:

```elixir
@callback post(url :: String.t(), post_body :: String.t(), options :: keyword()) ::
            Pillar.HttpClient.Response.t()
            | Pillar.HttpClient.TransportError.t()
            | %{__struct__: RuntimeError, message: String.t()}
```
