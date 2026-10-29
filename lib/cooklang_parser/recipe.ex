defmodule CooklangParser.Recipe do
  @moduledoc """
  A parsed recipe.
  """

  alias CooklangParser.Section

  defstruct metadata: %{}, sections: []

  @type t :: %__MODULE__{
          metadata: map(),
          sections: [Section.t()]
        }
end
