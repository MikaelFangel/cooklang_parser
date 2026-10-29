defmodule CooklangParser.Ingredient do
  @moduledoc """
  An ingredient, written as `@name{quantity%unit}(preparation)`.

  `:reference` is the path of a referenced recipe, as in `@./sauces/pesto{}`.
  """

  @enforce_keys [:name]
  defstruct [:name, :quantity, :unit, :preparation, :reference, optional: false]

  @type t :: %__MODULE__{
          name: String.t(),
          quantity: CooklangParser.quantity() | nil,
          unit: String.t() | nil,
          preparation: String.t() | nil,
          reference: String.t() | nil,
          optional: boolean()
        }
end
