defmodule LibsqlClient.Query do
  @moduledoc """
  Represents a SQL query to be executed.
  """

  @type t :: %__MODULE__{
          statement: String.t(),
          name: String.t() | nil
        }

  defstruct [:statement, :name]
end