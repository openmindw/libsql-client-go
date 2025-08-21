defmodule LibsqlClient.Protocol.File do
  @moduledoc """
  File-based SQLite implementation for local databases.

  This module provides direct access to local SQLite files using Elixir's
  built-in SQLite support or a NIF library.
  """

  @behaviour LibsqlClient.Protocol

  alias LibsqlClient.{Config, Error}

  @type t :: %__MODULE__{
          config: Config.t(),
          path: String.t()
        }

  defstruct [:config, :path]

  @impl LibsqlClient.Protocol
  def connect(%Config{path: path} = config) when is_binary(path) do
    # Remove file:// prefix if present
    clean_path = String.replace_prefix(path, "file://", "")

    conn = %__MODULE__{
      config: config,
      path: clean_path
    }

    {:ok, conn}
  end

  def connect(%Config{}) do
    {:error, %Error{message: "File path is required for file:// URLs"}}
  end

  @impl LibsqlClient.Protocol
  def disconnect(%__MODULE__{}) do
    # File connections are stateless
    :ok
  end

  @impl LibsqlClient.Protocol
  def ping(%__MODULE__{}) do
    # File access is always available if the file exists
    :ok
  end

  @impl LibsqlClient.Protocol
  def execute(%__MODULE__{}, _sql, _params, _opts) do
    # Implement file-based SQLite execution
    # This would require a SQLite NIF or using :sqlite3 if available
    {:error, %Error{message: "File protocol not yet implemented"}}
  end

  @impl LibsqlClient.Protocol
  def begin_transaction(%__MODULE__{}, _opts) do
    {:error, %Error{message: "File protocol not yet implemented"}}
  end

  @impl LibsqlClient.Protocol
  def commit_transaction(%__MODULE__{}, _tx_id, _opts) do
    {:error, %Error{message: "File protocol not yet implemented"}}
  end

  @impl LibsqlClient.Protocol
  def rollback_transaction(%__MODULE__{}, _tx_id, _opts) do
    {:error, %Error{message: "File protocol not yet implemented"}}
  end
end