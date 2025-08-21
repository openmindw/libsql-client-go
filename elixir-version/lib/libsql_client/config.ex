defmodule LibsqlClient.Config do
  @moduledoc """
  Configuration parsing and validation for libSQL connections.
  """

  @type t :: %__MODULE__{
          scheme: String.t(),
          host: String.t(),
          port: pos_integer() | nil,
          path: String.t() | nil,
          auth_token: String.t() | nil,
          tls: boolean(),
          proxy: String.t() | nil,
          pool_size: pos_integer(),
          timeout: pos_integer(),
          ssl_opts: keyword()
        }

  defstruct [
    :scheme,
    :host,
    :port,
    :path,
    :auth_token,
    :tls,
    :proxy,
    pool_size: 10,
    timeout: 5000,
    ssl_opts: []
  ]

  @doc """
  Parses a database URL and options into a configuration struct.

  ## Supported URL schemes

  - `libsql://` - Turso cloud databases
  - `https://` - HTTP with TLS
  - `http://` - HTTP without TLS  
  - `wss://` - WebSocket with TLS
  - `ws://` - WebSocket without TLS
  - `file://` - Local SQLite files

  ## Examples

      {:ok, config} = Config.parse("libsql://my-db.turso.io", auth_token: "token")
      {:ok, config} = Config.parse("file:///path/to/db.sqlite")

  """
  @spec parse(String.t(), keyword()) :: {:ok, t()} | {:error, term()}
  def parse(url, opts \\ []) do
    with {:ok, uri} <- URI.new(url),
         {:ok, config} <- build_config(uri, opts) do
      {:ok, validate_config(config)}
    else
      {:error, reason} -> {:error, reason}
      :error -> {:error, "Invalid URL: #{url}"}
    end
  end

  defp build_config(%URI{} = uri, opts) do
    config = %__MODULE__{
      scheme: normalize_scheme(uri.scheme),
      host: uri.host,
      port: uri.port,
      path: uri.path,
      auth_token: Keyword.get(opts, :auth_token),
      tls: determine_tls(uri.scheme, opts),
      proxy: Keyword.get(opts, :proxy),
      pool_size: Keyword.get(opts, :pool_size, 10),
      timeout: Keyword.get(opts, :timeout, 5000),
      ssl_opts: Keyword.get(opts, :ssl_opts, [])
    }

    {:ok, config}
  end

  defp normalize_scheme("libsql"), do: "https"
  defp normalize_scheme(scheme), do: scheme

  defp determine_tls(scheme, opts) do
    case Keyword.get(opts, :tls) do
      nil -> scheme in ["https", "wss", "libsql"]
      tls when is_boolean(tls) -> tls
    end
  end

  defp validate_config(%__MODULE__{} = config) do
    cond do
      config.scheme not in ["http", "https", "ws", "wss", "file"] ->
        raise ArgumentError, "Unsupported URL scheme: #{config.scheme}"

      config.scheme in ["http", "https", "ws", "wss"] and is_nil(config.host) ->
        raise ArgumentError, "Host is required for #{config.scheme} URLs"

      config.scheme == "file" and is_nil(config.path) ->
        raise ArgumentError, "Path is required for file URLs"

      config.pool_size <= 0 ->
        raise ArgumentError, "Pool size must be positive"

      config.timeout <= 0 ->
        raise ArgumentError, "Timeout must be positive"

      true ->
        config
    end
  end

  @doc """
  Returns the connection type based on the scheme.
  """
  @spec connection_type(t()) :: :http | :websocket | :file
  def connection_type(%__MODULE__{scheme: scheme}) do
    case scheme do
      scheme when scheme in ["http", "https"] -> :http
      scheme when scheme in ["ws", "wss"] -> :websocket
      "file" -> :file
    end
  end

  @doc """
  Returns the base URL for HTTP connections.
  """
  @spec base_url(t()) :: String.t()
  def base_url(%__MODULE__{scheme: scheme, host: host, port: port, path: path}) do
    port_part = if port, do: ":#{port}", else: ""
    path_part = path || ""
    "#{scheme}://#{host}#{port_part}#{path_part}"
  end

  @doc """
  Returns WebSocket URL for WebSocket connections.
  """
  @spec websocket_url(t()) :: String.t()
  def websocket_url(%__MODULE__{scheme: scheme, host: host, port: port, path: path}) do
    port_part = if port, do: ":#{port}", else: ""
    path_part = path || ""
    "#{scheme}://#{host}#{port_part}#{path_part}"
  end
end