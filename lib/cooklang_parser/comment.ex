defmodule CooklangParser.Comment do
  @moduledoc """
  A line or block comment.
  """

  @enforce_keys [:text]
  defstruct [:text]

  @type t :: %__MODULE__{text: String.t()}
end
