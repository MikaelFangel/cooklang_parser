defmodule CooklangParser.Timer do
  @moduledoc """
  A timer, written as `~name{quantity%unit}`.
  """

  defstruct [:name, :quantity, :unit]

  @type t :: %__MODULE__{
          name: String.t() | nil,
          quantity: CooklangParser.quantity() | nil,
          unit: String.t() | nil
        }
end
