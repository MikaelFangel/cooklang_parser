defmodule CooklangParser.Note do
  @moduledoc """
  A note, written as a line starting with `>`.
  """

  @enforce_keys [:text]
  defstruct [:text]

  @type t :: %__MODULE__{text: String.t()}
end
