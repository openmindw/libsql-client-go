defmodule LibsqlClientTest do
  use ExUnit.Case
  doctest LibsqlClient

  alias LibsqlClient.{Config, Error}

  describe "config parsing" do
    test "parses libsql:// URLs" do
      {:ok, config} = Config.parse("libsql://my-db.turso.io", auth_token: "token123")
      
      assert config.scheme == "https"
      assert config.host == "my-db.turso.io"
      assert config.auth_token == "token123"
      assert config.tls == true
    end

    test "parses https:// URLs" do
      {:ok, config} = Config.parse("https://example.com:8080/db")
      
      assert config.scheme == "https"
      assert config.host == "example.com"
      assert config.port == 8080
      assert config.path == "/db"
      assert config.tls == true
    end

    test "parses file:// URLs" do
      {:ok, config} = Config.parse("file:///path/to/db.sqlite")
      
      assert config.scheme == "file"
      assert config.path == "/path/to/db.sqlite"
    end

    test "determines connection type correctly" do
      {:ok, http_config} = Config.parse("https://example.com")
      {:ok, ws_config} = Config.parse("wss://example.com")
      {:ok, file_config} = Config.parse("file:///db.sqlite")

      assert Config.connection_type(http_config) == :http
      assert Config.connection_type(ws_config) == :websocket
      assert Config.connection_type(file_config) == :file
    end

    test "validates required fields" do
      assert_raise ArgumentError, fn ->
        Config.parse("invalid://", [])
      end
    end
  end

  describe "error handling" do
    test "creates error with message" do
      error = Error.new("Something went wrong")
      assert error.message == "Something went wrong"
      assert is_nil(error.code)
      assert is_nil(error.details)
    end

    test "creates error with code and details" do
      error = Error.new("DB error", "SQL_ERROR", %{line: 1})
      assert error.message == "DB error"
      assert error.code == "SQL_ERROR"
      assert error.details == %{line: 1}
    end
  end
end