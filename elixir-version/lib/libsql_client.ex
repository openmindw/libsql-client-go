defmodule LibsqlClient do
  @moduledoc """
  Elixir client for libSQL/Turso databases.

  This library provides a standardized interface for connecting to Turso databases
  using the Hrana protocol. It supports multiple connection types and integrates
  seamlessly with Phoenix and Ecto.

  ## Supported URL Schemes

  - `libsql://` - Turso cloud databases (auto-detects HTTP/HTTPS based on TLS setting)
  - `https://` - HTTP with TLS  
  - `http://` - HTTP without TLS
  - `wss://` - WebSocket with TLS
  - `ws://` - WebSocket without TLS
  - `file://` - Local SQLite files (requires sqlite3 NIF)

  ## Usage

  ### Basic Connection

      {:ok, conn} = LibsqlClient.connect("libsql://your-db.turso.io", 
        auth_token: "your-token")

  ### With Options

      {:ok, conn} = LibsqlClient.connect("libsql://your-db.turso.io", 
        auth_token: "your-token",
        tls: true,
        pool_size: 10)

  ### Execute Queries

      {:ok, result} = LibsqlClient.execute(conn, "SELECT * FROM users WHERE id = ?", [123])

  ### Transactions

      {:ok, result} = LibsqlClient.transaction(conn, fn conn ->
        LibsqlClient.execute!(conn, "INSERT INTO users (name) VALUES (?)", ["Alice"])
        LibsqlClient.execute!(conn, "INSERT INTO posts (user_id, title) VALUES (?, ?)", [1, "Hello"])
      end)

  ## Configuration

  The client can be configured in your `config.exs`:

      config :libsql_client,
        default_pool_size: 10,
        timeout: 5000,
        ssl_opts: [verify: :verify_peer]

  """

  alias LibsqlClient.{Connection, Config}

  @type connection :: Connection.t()
  @type result :: %{
          columns: [String.t()],
          rows: [[term()]],
          num_rows: non_neg_integer(),
          last_insert_id: integer() | nil
        }
  @type execute_opts :: [timeout: pos_integer()]

  @doc """
  Establishes a connection to a libSQL database.

  ## Options

  - `:auth_token` - Authentication token for Turso databases
  - `:tls` - Enable/disable TLS (boolean, defaults based on URL scheme)
  - `:proxy` - Proxy URL for HTTP connections
  - `:pool_size` - Connection pool size (default: 10)
  - `:timeout` - Connection timeout in milliseconds (default: 5000)
  - `:ssl_opts` - SSL options for secure connections

  ## Examples

      {:ok, conn} = LibsqlClient.connect("libsql://my-db.turso.io", 
        auth_token: "token_here")

      {:ok, conn} = LibsqlClient.connect("file:///path/to/db.sqlite")

  """
  @spec connect(String.t(), keyword()) :: {:ok, connection()} | {:error, term()}
  def connect(url, opts \\ []) do
    with {:ok, config} <- Config.parse(url, opts),
         {:ok, conn} <- Connection.start_link(config) do
      {:ok, conn}
    end
  end

  @doc """
  Executes a SQL statement and returns the result.

  ## Examples

      {:ok, result} = LibsqlClient.execute(conn, "SELECT * FROM users")
      {:ok, result} = LibsqlClient.execute(conn, "INSERT INTO users (name) VALUES (?)", ["Alice"])

  """
  @spec execute(connection(), String.t(), [term()], execute_opts()) :: 
          {:ok, result()} | {:error, term()}
  def execute(conn, sql, params \\ [], opts \\ []) do
    Connection.execute(conn, sql, params, opts)
  end

  @doc """
  Executes a SQL statement and returns the result, raising on error.
  """
  @spec execute!(connection(), String.t(), [term()], execute_opts()) :: result()
  def execute!(conn, sql, params \\ [], opts \\ []) do
    case execute(conn, sql, params, opts) do
      {:ok, result} -> result
      {:error, reason} -> raise LibsqlClient.Error, reason
    end
  end

  @doc """
  Executes multiple SQL statements in a transaction.

  The function will be called with a connection that is in transaction mode.
  If the function returns `{:ok, result}`, the transaction is committed.
  If it returns `{:error, reason}` or raises an exception, the transaction is rolled back.

  ## Examples

      {:ok, results} = LibsqlClient.transaction(conn, fn conn ->
        {:ok, _} = LibsqlClient.execute(conn, "INSERT INTO users (name) VALUES (?)", ["Alice"])
        {:ok, result} = LibsqlClient.execute(conn, "SELECT * FROM users WHERE name = ?", ["Alice"])
        {:ok, result}
      end)

  """
  @spec transaction(connection(), (connection() -> {:ok, term()} | {:error, term()})) ::
          {:ok, term()} | {:error, term()}
  def transaction(conn, fun) when is_function(fun, 1) do
    Connection.transaction(conn, fun)
  end

  @doc """
  Prepares a SQL statement for repeated execution.

  ## Examples

      {:ok, stmt} = LibsqlClient.prepare(conn, "SELECT * FROM users WHERE id = ?")
      {:ok, result} = LibsqlClient.execute_prepared(stmt, [123])

  """
  @spec prepare(connection(), String.t()) :: {:ok, term()} | {:error, term()}
  def prepare(conn, sql) do
    Connection.prepare(conn, sql)
  end

  @doc """
  Closes a connection.

  ## Examples

      :ok = LibsqlClient.close(conn)

  """
  @spec close(connection()) :: :ok
  def close(conn) do
    Connection.close(conn)
  end

  @doc """
  Pings the database to check connection health.

  ## Examples

      :ok = LibsqlClient.ping(conn)

  """
  @spec ping(connection()) :: :ok | {:error, term()}
  def ping(conn) do
    Connection.ping(conn)
  end
end