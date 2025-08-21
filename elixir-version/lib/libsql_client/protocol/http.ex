defmodule LibsqlClient.Protocol.HTTP do
  @moduledoc """
  HTTP implementation of the Hrana v2 protocol for libSQL.

  This module handles communication with libSQL databases over HTTP using
  the Hrana v2 protocol. It supports connection pooling, authentication,
  and all standard SQL operations.
  """

  @behaviour LibsqlClient.Protocol

  alias LibsqlClient.{Config, Error}

  @type t :: %__MODULE__{
          config: Config.t(),
          base_url: String.t(),
          headers: [{String.t(), String.t()}],
          replication_index: non_neg_integer()
        }

  defstruct [:config, :base_url, :headers, replication_index: 0]

  @hrana_v2_endpoint "/v2/pipeline"
  @client_version "libsql-elixir-0.1.0"

  @impl LibsqlClient.Protocol
  def connect(%Config{} = config) do
    base_url = Config.base_url(config)
    headers = build_headers(config)

    conn = %__MODULE__{
      config: config,
      base_url: base_url,
      headers: headers
    }

    # Test connection with a ping
    case ping(conn) do
      :ok -> {:ok, conn}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl LibsqlClient.Protocol
  def disconnect(_conn) do
    # HTTP connections are stateless, nothing to clean up
    :ok
  end

  @impl LibsqlClient.Protocol
  def ping(%__MODULE__{} = conn) do
    request = %{
      "requests" => [
        %{
          "type" => "execute",
          "stmt" => %{
            "sql" => "SELECT 1",
            "args" => [],
            "replication_index" => conn.replication_index
          }
        }
      ]
    }

    case send_pipeline_request(conn, request) do
      {:ok, _response, _conn} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @impl LibsqlClient.Protocol
  def execute(%__MODULE__{} = conn, sql, params, _opts) do
    request = %{
      "requests" => [
        %{
          "type" => "execute",
          "stmt" => %{
            "sql" => sql,
            "args" => encode_params(params),
            "replication_index" => conn.replication_index
          }
        }
      ]
    }

    case send_pipeline_request(conn, request) do
      {:ok, response, updated_conn} ->
        case parse_execute_response(response) do
          {:ok, result} -> {:ok, result}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl LibsqlClient.Protocol
  def begin_transaction(%__MODULE__{} = conn, _opts) do
    request = %{
      "requests" => [
        %{
          "type" => "execute",
          "stmt" => %{
            "sql" => "BEGIN",
            "args" => [],
            "replication_index" => conn.replication_index
          }
        }
      ]
    }

    case send_pipeline_request(conn, request) do
      {:ok, _response, _updated_conn} ->
        # Generate a transaction ID (in real implementation, this might come from server)
        tx_id = :crypto.strong_rand_bytes(16) |> Base.encode16()
        {:ok, tx_id}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl LibsqlClient.Protocol
  def commit_transaction(%__MODULE__{} = conn, _tx_id, _opts) do
    request = %{
      "requests" => [
        %{
          "type" => "execute",
          "stmt" => %{
            "sql" => "COMMIT",
            "args" => [],
            "replication_index" => conn.replication_index
          }
        }
      ]
    }

    case send_pipeline_request(conn, request) do
      {:ok, _response, _updated_conn} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @impl LibsqlClient.Protocol
  def rollback_transaction(%__MODULE__{} = conn, _tx_id, _opts) do
    request = %{
      "requests" => [
        %{
          "type" => "execute",
          "stmt" => %{
            "sql" => "ROLLBACK",
            "args" => [],
            "replication_index" => conn.replication_index
          }
        }
      ]
    }

    case send_pipeline_request(conn, request) do
      {:ok, _response, _updated_conn} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  ## Private Functions

  defp build_headers(%Config{auth_token: auth_token}) do
    headers = [
      {"Content-Type", "application/json"},
      {"x-libsql-client-version", @client_version}
    ]

    if auth_token do
      [{"Authorization", "Bearer #{auth_token}"} | headers]
    else
      headers
    end
  end

  defp send_pipeline_request(%__MODULE__{} = conn, request) do
    url = conn.base_url <> @hrana_v2_endpoint
    body = Jason.encode!(request)

    http_opts = [
      timeout: conn.config.timeout,
      recv_timeout: conn.config.timeout
    ]

    case Tesla.post(url, body, headers: conn.headers, opts: http_opts) do
      {:ok, %Tesla.Env{status: 200, body: response_body}} ->
        case Jason.decode(response_body) do
          {:ok, response} ->
            updated_conn = update_replication_index(conn, response)
            {:ok, response, updated_conn}

          {:error, reason} ->
            {:error, %Error{message: "Failed to parse response: #{inspect(reason)}"}}
        end

      {:ok, %Tesla.Env{status: status, body: body}} ->
        {:error, %Error{message: "HTTP #{status}: #{body}"}}

      {:error, reason} ->
        {:error, %Error{message: "HTTP request failed: #{inspect(reason)}"}}
    end
  end

  defp encode_params(params) when is_list(params) do
    Enum.map(params, &encode_param/1)
  end

  defp encode_param(nil), do: %{"type" => "null"}
  defp encode_param(value) when is_integer(value), do: %{"type" => "integer", "value" => to_string(value)}
  defp encode_param(value) when is_float(value), do: %{"type" => "float", "value" => to_string(value)}
  defp encode_param(value) when is_binary(value), do: %{"type" => "text", "value" => value}
  defp encode_param(value) when is_boolean(value), do: %{"type" => "integer", "value" => if(value, do: "1", else: "0")}

  defp encode_param(value) do
    {:error, %Error{message: "Unsupported parameter type: #{inspect(value)}"}}
  end

  defp parse_execute_response(%{"results" => [result | _]}) do
    case result do
      %{"type" => "ok", "response" => %{"type" => "execute", "result" => result_data}} ->
        parse_result_data(result_data)

      %{"type" => "error", "error" => error} ->
        {:error, %Error{
          message: error["message"],
          code: error["code"]
        }}

      _ ->
        {:error, %Error{message: "Unexpected response format"}}
    end
  end

  defp parse_result_data(result_data) do
    columns = Enum.map(result_data["cols"] || [], & &1["name"])
    rows = Enum.map(result_data["rows"] || [], &parse_row/1)

    result = %{
      columns: columns,
      rows: rows,
      num_rows: length(rows),
      last_insert_id: parse_last_insert_id(result_data["last_insert_rowid"])
    }

    {:ok, result}
  end

  defp parse_row(row) when is_list(row) do
    Enum.map(row, &parse_value/1)
  end

  defp parse_value(%{"type" => "null"}), do: nil
  defp parse_value(%{"type" => "integer", "value" => value}), do: String.to_integer(value)
  defp parse_value(%{"type" => "float", "value" => value}), do: String.to_float(value)
  defp parse_value(%{"type" => "text", "value" => value}), do: value
  defp parse_value(%{"type" => "blob", "value" => value}), do: Base.decode64!(value)

  defp parse_last_insert_id(nil), do: nil
  defp parse_last_insert_id(value) when is_binary(value), do: String.to_integer(value)
  defp parse_last_insert_id(value) when is_integer(value), do: value

  defp update_replication_index(conn, %{"results" => results}) do
    max_index = 
      results
      |> Enum.flat_map(fn
        %{"response" => %{"result" => %{"replication_index" => index}}} when is_integer(index) -> [index]
        _ -> []
      end)
      |> Enum.max(fn -> conn.replication_index end)

    %{conn | replication_index: max_index}
  end
end