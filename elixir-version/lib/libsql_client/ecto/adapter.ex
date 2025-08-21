defmodule LibsqlClient.Ecto.Adapter do
  @moduledoc """
  Ecto adapter for libSQL databases.

  This adapter allows Phoenix applications to use libSQL/Turso databases
  through Ecto's standard interface.

  ## Configuration

  Add to your Phoenix application's config:

      config :my_app, MyApp.Repo,
        adapter: LibsqlClient.Ecto.Adapter,
        url: "libsql://my-database.turso.io",
        auth_token: System.get_env("TURSO_AUTH_TOKEN"),
        pool_size: 10

  ## Usage in Phoenix

      defmodule MyApp.Repo do
        use Ecto.Repo,
          otp_app: :my_app,
          adapter: LibsqlClient.Ecto.Adapter
      end

  """

  use Ecto.Adapters.SQL, driver: :libsql_client

  alias LibsqlClient.{Connection, Config}

  @behaviour Ecto.Adapter
  @behaviour Ecto.Adapter.Migration
  @behaviour Ecto.Adapter.Transaction

  ## Ecto.Adapter callbacks

  @impl Ecto.Adapter
  def ensure_all_started(_config, _type) do
    {:ok, [:libsql_client]}
  end

  @impl Ecto.Adapter
  def init(config) do
    # Parse configuration and validate
    url = Keyword.get(config, :url) || Keyword.get(config, :database)
    auth_token = Keyword.get(config, :auth_token)
    
    unless url do
      raise ArgumentError, "Missing :url or :database in repository configuration"
    end

    # Build libSQL client config
    client_opts = [
      auth_token: auth_token,
      pool_size: Keyword.get(config, :pool_size, 10),
      timeout: Keyword.get(config, :timeout, 5000),
      tls: Keyword.get(config, :tls),
      proxy: Keyword.get(config, :proxy),
      ssl_opts: Keyword.get(config, :ssl_opts, [])
    ]

    case Config.parse(url, client_opts) do
      {:ok, client_config} ->
        # Store the client config for later use
        config = Keyword.put(config, :libsql_config, client_config)
        {:ok, Connection.child_spec(config), %{}}

      {:error, reason} ->
        raise ArgumentError, "Invalid libSQL configuration: #{inspect(reason)}"
    end
  end

  @impl Ecto.Adapter
  def checkout(adapter_meta, config, fun) do
    DBConnection.run(adapter_meta.pid, fun, config)
  end

  @impl Ecto.Adapter
  def checked_out?(adapter_meta) do
    DBConnection.checked_out?(adapter_meta.pid)
  end

  ## Ecto.Adapter.Migration callbacks

  @impl Ecto.Adapter.Migration
  def supports_ddl_transaction?, do: true

  @impl Ecto.Adapter.Migration
  def execute_ddl(adapter_meta, command, opts) do
    case command do
      {:create, %Ecto.Migration.Table{} = table, columns} ->
        execute_sql(adapter_meta, create_table_sql(table, columns), [], opts)

      {:drop, %Ecto.Migration.Table{} = table, _mode} ->
        execute_sql(adapter_meta, drop_table_sql(table), [], opts)

      {:alter, %Ecto.Migration.Table{} = table, changes} ->
        execute_sql(adapter_meta, alter_table_sql(table, changes), [], opts)

      {:create, %Ecto.Migration.Index{} = index} ->
        execute_sql(adapter_meta, create_index_sql(index), [], opts)

      {:drop, %Ecto.Migration.Index{} = index, _mode} ->
        execute_sql(adapter_meta, drop_index_sql(index), [], opts)

      _ ->
        raise ArgumentError, "Unsupported DDL command: #{inspect(command)}"
    end
  end

  ## Ecto.Adapter.Transaction callbacks

  @impl Ecto.Adapter.Transaction
  def transaction(adapter_meta, opts, fun) do
    DBConnection.transaction(adapter_meta.pid, fun, opts)
  end

  @impl Ecto.Adapter.Transaction
  def in_transaction?(adapter_meta) do
    DBConnection.in_transaction?(adapter_meta.pid)
  end

  @impl Ecto.Adapter.Transaction
  def rollback(adapter_meta, value) do
    DBConnection.rollback(adapter_meta.pid, value)
  end

  ## SQL Generation (simplified for SQLite)

  defp create_table_sql(%Ecto.Migration.Table{name: name}, columns) do
    column_definitions = Enum.map(columns, &column_definition/1)
    "CREATE TABLE #{name} (#{Enum.join(column_definitions, ", ")})"
  end

  defp drop_table_sql(%Ecto.Migration.Table{name: name}) do
    "DROP TABLE #{name}"
  end

  defp alter_table_sql(%Ecto.Migration.Table{name: name}, changes) do
    # SQLite has limited ALTER TABLE support, this is simplified
    alterations = Enum.map(changes, fn
      {:add, column_name, type, opts} ->
        "ADD COLUMN #{column_definition({:add, column_name, type, opts})}"
      {:remove, column_name} ->
        # SQLite doesn't support DROP COLUMN directly
        raise "DROP COLUMN not supported in SQLite"
    end)

    "ALTER TABLE #{name} #{Enum.join(alterations, ", ")}"
  end

  defp create_index_sql(%Ecto.Migration.Index{table: table, columns: columns, name: name}) do
    column_list = Enum.join(columns, ", ")
    "CREATE INDEX #{name} ON #{table} (#{column_list})"
  end

  defp drop_index_sql(%Ecto.Migration.Index{name: name}) do
    "DROP INDEX #{name}"
  end

  defp column_definition({:add, name, type, opts}) do
    type_sql = ecto_type_to_sql(type)
    constraints = build_constraints(opts)
    "#{name} #{type_sql}#{constraints}"
  end

  defp ecto_type_to_sql(:id), do: "INTEGER PRIMARY KEY"
  defp ecto_type_to_sql(:binary_id), do: "TEXT PRIMARY KEY"
  defp ecto_type_to_sql(:integer), do: "INTEGER"
  defp ecto_type_to_sql(:bigint), do: "INTEGER"
  defp ecto_type_to_sql(:float), do: "REAL"
  defp ecto_type_to_sql(:string), do: "TEXT"
  defp ecto_type_to_sql(:text), do: "TEXT"
  defp ecto_type_to_sql(:boolean), do: "INTEGER"
  defp ecto_type_to_sql(:date), do: "TEXT"
  defp ecto_type_to_sql(:time), do: "TEXT"
  defp ecto_type_to_sql(:datetime), do: "TEXT"
  defp ecto_type_to_sql(:naive_datetime), do: "TEXT"
  defp ecto_type_to_sql(:utc_datetime), do: "TEXT"
  defp ecto_type_to_sql(:binary), do: "BLOB"
  defp ecto_type_to_sql(type), do: to_string(type)

  defp build_constraints(opts) do
    constraints = []

    constraints = if Keyword.get(opts, :null, true) == false do
      [" NOT NULL" | constraints]
    else
      constraints
    end

    constraints = if Keyword.has_key?(opts, :default) do
      default = Keyword.get(opts, :default)
      [" DEFAULT #{format_default(default)}" | constraints]
    else
      constraints
    end

    Enum.join(constraints)
  end

  defp format_default(nil), do: "NULL"
  defp format_default(value) when is_binary(value), do: "'#{value}'"
  defp format_default(value) when is_number(value), do: to_string(value)
  defp format_default(true), do: "1"
  defp format_default(false), do: "0"

  defp execute_sql(adapter_meta, sql, params, opts) do
    case DBConnection.execute(adapter_meta.pid, %LibsqlClient.Query{statement: sql}, params, opts) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, reason}
    end
  end
end