defmodule LibsqlClient.Protocol do
  @moduledoc """
  Protocol abstraction for different connection types.
  """

  alias LibsqlClient.{Config, Protocol.HTTP, Protocol.WebSocket, Protocol.File}

  @type t :: HTTP.t() | WebSocket.t() | File.t()

  @callback connect(Config.t()) :: {:ok, t()} | {:error, term()}
  @callback disconnect(t()) :: :ok
  @callback ping(t()) :: :ok | {:error, term()}
  @callback execute(t(), String.t(), [term()], keyword()) :: {:ok, term()} | {:error, term()}
  @callback begin_transaction(t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  @callback commit_transaction(t(), String.t(), keyword()) :: :ok | {:error, term()}
  @callback rollback_transaction(t(), String.t(), keyword()) :: :ok | {:error, term()}

  @doc """
  Creates a protocol connection based on configuration.
  """
  @spec connect(Config.t()) :: {:ok, t()} | {:error, term()}
  def connect(%Config{} = config) do
    case Config.connection_type(config) do
      :http -> HTTP.connect(config)
      :websocket -> WebSocket.connect(config)
      :file -> File.connect(config)
    end
  end

  @doc """
  Disconnects a protocol connection.
  """
  @spec disconnect(t()) :: :ok
  def disconnect(%HTTP{} = conn), do: HTTP.disconnect(conn)
  def disconnect(%WebSocket{} = conn), do: WebSocket.disconnect(conn)
  def disconnect(%File{} = conn), do: File.disconnect(conn)

  @doc """
  Pings the connection to check health.
  """
  @spec ping(t()) :: :ok | {:error, term()}
  def ping(%HTTP{} = conn), do: HTTP.ping(conn)
  def ping(%WebSocket{} = conn), do: WebSocket.ping(conn)
  def ping(%File{} = conn), do: File.ping(conn)

  @doc """
  Executes a SQL statement.
  """
  @spec execute(t(), String.t(), [term()], keyword()) :: {:ok, term()} | {:error, term()}
  def execute(%HTTP{} = conn, sql, params, opts), do: HTTP.execute(conn, sql, params, opts)
  def execute(%WebSocket{} = conn, sql, params, opts), do: WebSocket.execute(conn, sql, params, opts)
  def execute(%File{} = conn, sql, params, opts), do: File.execute(conn, sql, params, opts)

  @doc """
  Begins a transaction.
  """
  @spec begin_transaction(t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def begin_transaction(%HTTP{} = conn, opts), do: HTTP.begin_transaction(conn, opts)
  def begin_transaction(%WebSocket{} = conn, opts), do: WebSocket.begin_transaction(conn, opts)
  def begin_transaction(%File{} = conn, opts), do: File.begin_transaction(conn, opts)

  @doc """
  Commits a transaction.
  """
  @spec commit_transaction(t(), String.t(), keyword()) :: :ok | {:error, term()}
  def commit_transaction(%HTTP{} = conn, tx_id, opts), do: HTTP.commit_transaction(conn, tx_id, opts)
  def commit_transaction(%WebSocket{} = conn, tx_id, opts), do: WebSocket.commit_transaction(conn, tx_id, opts)
  def commit_transaction(%File{} = conn, tx_id, opts), do: File.commit_transaction(conn, tx_id, opts)

  @doc """
  Rolls back a transaction.
  """
  @spec rollback_transaction(t(), String.t(), keyword()) :: :ok | {:error, term()}
  def rollback_transaction(%HTTP{} = conn, tx_id, opts), do: HTTP.rollback_transaction(conn, tx_id, opts)
  def rollback_transaction(%WebSocket{} = conn, tx_id, opts), do: WebSocket.rollback_transaction(conn, tx_id, opts)
  def rollback_transaction(%File{} = conn, tx_id, opts), do: File.rollback_transaction(conn, tx_id, opts)
end