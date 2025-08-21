defmodule LibsqlClient.Connection do
  @moduledoc """
  Connection management for libSQL databases.

  This module implements the DBConnection behavior and manages connections
  to libSQL databases via HTTP or WebSocket protocols.
  """

  use DBConnection

  alias LibsqlClient.{Config, Protocol}

  @type t :: %__MODULE__{
          config: Config.t(),
          protocol: Protocol.t(),
          state: :idle | :transaction,
          transaction_id: String.t() | nil
        }

  defstruct [:config, :protocol, state: :idle, transaction_id: nil]

  ## DBConnection Callbacks

  @impl DBConnection
  def connect(opts) do
    config = Keyword.fetch!(opts, :config)

    case Protocol.connect(config) do
      {:ok, protocol} ->
        conn = %__MODULE__{
          config: config,
          protocol: protocol,
          state: :idle
        }

        {:ok, conn}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl DBConnection
  def disconnect(_reason, %__MODULE__{protocol: protocol}) do
    Protocol.disconnect(protocol)
  end

  @impl DBConnection
  def checkout(%__MODULE__{} = conn) do
    {:ok, conn}
  end

  @impl DBConnection
  def checkin(%__MODULE__{} = conn) do
    {:ok, conn}
  end

  @impl DBConnection
  def ping(%__MODULE__{protocol: protocol}) do
    Protocol.ping(protocol)
  end

  @impl DBConnection
  def handle_execute(query, params, opts, %__MODULE__{} = conn) do
    case Protocol.execute(conn.protocol, query.statement, params, opts) do
      {:ok, result} ->
        {:ok, result, conn}

      {:error, reason} ->
        {:error, reason, conn}
    end
  end

  @impl DBConnection
  def handle_prepare(query, _opts, %__MODULE__{} = conn) do
    prepared_query = %{query | statement: query.statement}
    {:ok, prepared_query, conn}
  end

  @impl DBConnection
  def handle_close(_query, _opts, %__MODULE__{} = conn) do
    {:ok, nil, conn}
  end

  @impl DBConnection
  def handle_begin(opts, %__MODULE__{state: :idle} = conn) do
    case Protocol.begin_transaction(conn.protocol, opts) do
      {:ok, tx_id} ->
        conn = %{conn | state: :transaction, transaction_id: tx_id}
        {:ok, nil, conn}

      {:error, reason} ->
        {:error, reason, conn}
    end
  end

  def handle_begin(_opts, %__MODULE__{state: :transaction} = conn) do
    {:error, :already_in_transaction, conn}
  end

  @impl DBConnection
  def handle_commit(opts, %__MODULE__{state: :transaction} = conn) do
    case Protocol.commit_transaction(conn.protocol, conn.transaction_id, opts) do
      :ok ->
        conn = %{conn | state: :idle, transaction_id: nil}
        {:ok, nil, conn}

      {:error, reason} ->
        {:error, reason, conn}
    end
  end

  def handle_commit(_opts, %__MODULE__{state: :idle} = conn) do
    {:error, :not_in_transaction, conn}
  end

  @impl DBConnection
  def handle_rollback(opts, %__MODULE__{state: :transaction} = conn) do
    case Protocol.rollback_transaction(conn.protocol, conn.transaction_id, opts) do
      :ok ->
        conn = %{conn | state: :idle, transaction_id: nil}
        {:ok, nil, conn}

      {:error, reason} ->
        {:error, reason, conn}
    end
  end

  def handle_rollback(_opts, %__MODULE__{state: :idle} = conn) do
    {:error, :not_in_transaction, conn}
  end

  @impl DBConnection
  def handle_status(_opts, %__MODULE__{state: state} = conn) do
    {state, conn}
  end

  ## Public API

  @doc """
  Starts a connection process.
  """
  @spec start_link(Config.t(), keyword()) :: {:ok, pid()} | {:error, term()}
  def start_link(config, opts \\ []) do
    opts = Keyword.put(opts, :config, config)
    DBConnection.start_link(__MODULE__, opts)
  end

  @doc """
  Executes a SQL statement.
  """
  @spec execute(DBConnection.conn(), String.t(), [term()], keyword()) ::
          {:ok, term()} | {:error, term()}
  def execute(conn, sql, params \\ [], opts \\ []) do
    query = %LibsqlClient.Query{statement: sql}
    DBConnection.execute(conn, query, params, opts)
  end

  @doc """
  Prepares a SQL statement.
  """
  @spec prepare(DBConnection.conn(), String.t()) :: {:ok, term()} | {:error, term()}
  def prepare(conn, sql) do
    query = %LibsqlClient.Query{statement: sql}
    DBConnection.prepare(conn, query)
  end

  @doc """
  Executes a function in a transaction.
  """
  @spec transaction(DBConnection.conn(), (DBConnection.conn() -> term())) ::
          {:ok, term()} | {:error, term()}
  def transaction(conn, fun) when is_function(fun, 1) do
    DBConnection.transaction(conn, fun)
  end

  @doc """
  Closes a connection.
  """
  @spec close(DBConnection.conn()) :: :ok
  def close(conn) do
    DBConnection.close(conn)
  end

  @doc """
  Pings the database connection.
  """
  @spec ping(DBConnection.conn()) :: :ok | {:error, term()}
  def ping(conn) do
    DBConnection.ping(conn)
  end
end