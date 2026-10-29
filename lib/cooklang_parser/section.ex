defmodule CooklangParser.Section do
  @moduledoc """
  A section of a recipe and the blocks in it.

  Content before the first section heading belongs to a section named `nil`.
  """

  alias CooklangParser.{Comment, Note, Step}

  defstruct name: nil, content: []

  @type block :: Step.t() | Note.t() | Comment.t()

  @type t :: %__MODULE__{
          name: String.t() | nil,
          content: [block()]
        }
end
