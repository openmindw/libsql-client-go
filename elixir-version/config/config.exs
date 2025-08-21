import Config

# Configuration for LibSQL Client

# Default pool configuration
config :libsql_client,
  default_pool_size: 10,
  timeout: 5000,
  ssl_opts: [verify: :verify_peer]

# Example database configurations for different environments
if config_env() == :dev do
  config :libsql_client, :example_db,
    url: "libsql://example-dev.turso.io",
    auth_token: System.get_env("TURSO_AUTH_TOKEN_DEV"),
    pool_size: 5
end

if config_env() == :test do
  config :libsql_client, :test_db,
    url: "file:///tmp/test.db",
    pool_size: 1
end

if config_env() == :prod do
  config :libsql_client, :production_db,
    url: System.get_env("DATABASE_URL"),
    auth_token: System.get_env("TURSO_AUTH_TOKEN"),
    pool_size: 20
end