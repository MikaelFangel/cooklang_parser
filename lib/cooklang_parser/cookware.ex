defmodule CooklangParser.Cookware do
  @moduledoc """
  A piece of cookware, written as `#name{quantity}`.
  """

  @enforce_keys [:name]
  defstruct [:name, :quantity, :unit, optional: false]

  @type t :: %__MODULE__{
          name: String.t(),
          quantity: CooklangParser.quantity() | nil,
          unit: String.t() | nil,
          optional: boolean()
        }
end
