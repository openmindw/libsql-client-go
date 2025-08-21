defmodule LibsqlClient.Error do
  @moduledoc """
  Exception for libSQL client errors.
  """

  defexception [:message, :code, :details]

  @type t :: %__MODULE__{
          message: String.t(),
          code: String.t() | nil,
          details: map() | nil
        }

  def new(message, code \\ nil, details \\ nil) do
    %__MODULE__{
      message: message,
      code: code,
      details: details
    }
  end
end