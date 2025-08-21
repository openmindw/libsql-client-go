# LibSQL Client for Elixir

An Elixir client library for [libSQL](https://turso.tech/libsql) databases, providing seamless integration with Phoenix applications through Ecto.

## Features

- 🚀 **Full Turso Support** - Connect to Turso cloud databases
- 🔌 **Multiple Protocols** - HTTP (Hrana v2) and WebSocket (Hrana v1) support
- 🏗️ **Phoenix Integration** - Native Ecto adapter for Phoenix applications
- 🔒 **Authentication** - Built-in JWT token authentication
- 🌐 **Connection Pooling** - Efficient connection management
- 📋 **Transactions** - Full transaction support with rollback
- 🎯 **Type Safety** - Proper Elixir type mapping
- 🛡️ **Error Handling** - Comprehensive error reporting

## Installation

Add `libsql_client` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:libsql_client, "~> 0.1.0"}
  ]
end
```

## Quick Start

### Basic Usage

```elixir
# Connect to a Turso database
{:ok, conn} = LibsqlClient.connect("libsql://my-database.turso.io", 
  auth_token: "your-auth-token")

# Execute a simple query
{:ok, result} = LibsqlClient.execute(conn, "SELECT * FROM users")

# Execute with parameters
{:ok, result} = LibsqlClient.execute(conn, 
  "SELECT * FROM users WHERE age > ? AND city = ?", 
  [18, "San Francisco"])

# Use transactions
{:ok, results} = LibsqlClient.transaction(conn, fn conn ->
  {:ok, _} = LibsqlClient.execute(conn, "INSERT INTO users (name, email) VALUES (?, ?)", 
    ["Alice", "alice@example.com"])
  {:ok, user} = LibsqlClient.execute(conn, "SELECT * FROM users WHERE email = ?", 
    ["alice@example.com"])
  {:ok, user}
end)
```

### Phoenix/Ecto Integration

#### 1. Configure your repository

```elixir
# config/config.exs
config :my_app, MyApp.Repo,
  adapter: LibsqlClient.Ecto.Adapter,
  url: "libsql://my-database.turso.io",
  auth_token: System.get_env("TURSO_AUTH_TOKEN"),
  pool_size: 10
```

#### 2. Define your repository

```elixir
# lib/my_app/repo.ex
defmodule MyApp.Repo do
  use Ecto.Repo,
    otp_app: :my_app,
    adapter: LibsqlClient.Ecto.Adapter
end
```

#### 3. Define schemas and use them normally

```elixir
defmodule MyApp.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :name, :string
    field :email, :string
    field :age, :integer

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :email, :age])
    |> validate_required([:name, :email])
    |> unique_constraint(:email)
  end
end

# Use with standard Ecto operations
user = %MyApp.User{}
|> MyApp.User.changeset(%{name: "Alice", email: "alice@example.com", age: 30})
|> MyApp.Repo.insert!()

users = MyApp.Repo.all(MyApp.User)
alice = MyApp.Repo.get_by(MyApp.User, email: "alice@example.com")
```

## Configuration

### Connection URLs

LibSQL Client supports multiple URL schemes:

- `libsql://` - Turso cloud databases (recommended)
- `https://` - HTTP with TLS
- `http://` - HTTP without TLS
- `wss://` - WebSocket with TLS
- `ws://` - WebSocket without TLS
- `file://` - Local SQLite files

### Options

```elixir
LibsqlClient.connect(url, [
  # Authentication token for Turso databases
  auth_token: "your-token",
  
  # Enable/disable TLS (auto-detected from URL by default)
  tls: true,
  
  # Proxy URL for HTTP connections
  proxy: "http://proxy.example.com:8080",
  
  # Connection pool size (default: 10)
  pool_size: 10,
  
  # Connection timeout in milliseconds (default: 5000)
  timeout: 5000,
  
  # SSL options for secure connections
  ssl_opts: [verify: :verify_peer]
])
```

## Advanced Usage

### Prepared Statements

```elixir
{:ok, stmt} = LibsqlClient.prepare(conn, "SELECT * FROM users WHERE age > ?")
{:ok, result1} = LibsqlClient.execute_prepared(stmt, [18])
{:ok, result2} = LibsqlClient.execute_prepared(stmt, [25])
```

### Connection Health Monitoring

```elixir
case LibsqlClient.ping(conn) do
  :ok -> IO.puts("Connection is healthy")
  {:error, reason} -> IO.puts("Connection issue: #{inspect(reason)}")
end
```

### Error Handling

```elixir
case LibsqlClient.execute(conn, "INVALID SQL") do
  {:ok, result} -> 
    handle_success(result)
  
  {:error, %LibsqlClient.Error{message: message, code: code}} ->
    Logger.error("SQL Error [#{code}]: #{message}")
    handle_error()
end
```

## Migrations with Phoenix

```elixir
defmodule MyApp.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users) do
      add :name, :string, null: false
      add :email, :string, null: false
      add :age, :integer
      add :is_active, :boolean, default: true

      timestamps()
    end

    create unique_index(:users, [:email])
  end
end
```

## Environment Variables

For production deployments, use environment variables:

```bash
export TURSO_DATABASE_URL="libsql://my-database.turso.io"
export TURSO_AUTH_TOKEN="your-auth-token"
```

```elixir
# config/runtime.exs
config :my_app, MyApp.Repo,
  url: System.get_env("TURSO_DATABASE_URL"),
  auth_token: System.get_env("TURSO_AUTH_TOKEN")
```

## Performance Tips

1. **Use Connection Pooling**: Configure appropriate pool sizes based on your application load
2. **Batch Operations**: Use transactions to group multiple operations
3. **Prepared Statements**: Reuse prepared statements for repeated queries
4. **Connection Health**: Monitor connection health with periodic pings

## Comparison with Go Version

This Elixir implementation provides equivalent functionality to the Go version:

| Feature | Go Version | Elixir Version |
|---------|------------|----------------|
| HTTP Protocol (Hrana v2) | ✅ | ✅ |
| WebSocket Protocol (Hrana v1) | ✅ | ✅ |
| Authentication | ✅ | ✅ |
| Connection Pooling | ✅ | ✅ |
| Transactions | ✅ | ✅ |
| Prepared Statements | ✅ | ✅ |
| Parameter Binding | ✅ | ✅ |
| Error Handling | ✅ | ✅ |
| Local SQLite | ✅ | ⏳ |
| Framework Integration | database/sql | Ecto/Phoenix |

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Run tests (`mix test`)
4. Commit your changes (`git commit -am 'Add amazing feature'`)
5. Push to the branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](../LICENSE) file for details.

## Related

- [Turso Documentation](https://docs.turso.tech/)
- [libSQL](https://turso.tech/libsql)
- [Go libSQL Client](../go-version/) - The original Go implementation
- [Hrana Protocol](https://github.com/tursodatabase/libsql/blob/main/docs/HRANA_3_SPEC.md)