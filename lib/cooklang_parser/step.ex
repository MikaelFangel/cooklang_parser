defmodule CooklangParser.Step do
  @moduledoc """
  A step of a recipe and the fragments in it.

  Text is a plain string. Line breaks are kept as `"\\n"` in the text.
  """

  alias CooklangParser.{Comment, Cookware, Ingredient, Timer}

  defstruct fragments: []

  @type fragment :: String.t() | Ingredient.t() | Cookware.t() | Timer.t() | Comment.t()

  @type t :: %__MODULE__{fragments: [fragment()]}
end
