defmodule LibsqlClient.Application do
  @moduledoc """
  The LibsqlClient Application.
  """

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Connection supervisor for managing pools
      {DynamicSupervisor, strategy: :one_for_one, name: LibsqlClient.ConnectionSupervisor}
    ]

    opts = [strategy: :one_for_one, name: LibsqlClient.Supervisor]
    Supervisor.start_link(children, opts)
  end
end