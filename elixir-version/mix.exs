defmodule LibsqlClient.MixProject do
  use Mix.Project

  def project do
    [
      app: :libsql_client,
      version: "0.1.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto, :ssl, :inets],
      mod: {LibsqlClient.Application, []}
    ]
  end

  defp description do
    """
    Elixir client for libSQL/Turso databases. Supports HTTP and WebSocket connections
    via the Hrana protocol with full Phoenix/Ecto integration.
    """
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/openmindw/libsql-client-go"},
      maintainers: ["LibSQL Team"]
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.4"},
      {:tesla, "~> 1.8"},
      {:websockex, "~> 0.4"},
      {:db_connection, "~> 2.5"},
      {:ecto_sql, "~> 3.10", optional: true},
      {:ex_doc, "~> 0.31", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false}
    ]
  end
end