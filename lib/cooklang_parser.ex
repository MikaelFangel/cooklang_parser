defmodule CooklangParser do
  @moduledoc """
  Implementation of the Cooklang spec.
  """
  import NimbleParsec

  alias CooklangParser.{Comment, Cookware, Ingredient, Note, Recipe, Section, Step, Timer}

  @type quantity :: integer() | float() | String.t()

  whitespace = ascii_string([?\s, ?\t], min: 1)
  newline = choice([string("\r\n"), string("\n")])
  line_content = utf8_string([not: ?\r, not: ?\n], min: 0)

  metadata =
    ignore(string("---") |> optional(whitespace) |> concat(newline))
    |> repeat(
      lookahead_not(string("---"))
      |> concat(line_content)
      |> concat(newline |> replace("\n"))
    )
    |> ignore(string("---") |> optional(whitespace) |> optional(newline))
    |> post_traverse({:parse_yaml, []})
    |> unwrap_and_tag(:metadata)

  comment =
    ignore(string("--"))
    |> lookahead_not(string("-"))
    |> concat(line_content)
    |> map({String, :trim, []})
    |> unwrap_and_tag(:text)
    |> reduce({:build_struct, [Comment]})
    |> post_traverse({:filter_comment, []})

  block_comment =
    ignore(string("[-"))
    |> repeat(lookahead_not(string("-]")) |> choice([newline, utf8_char(not: ?\r)]))
    |> ignore(string("-]"))
    |> reduce({List, :to_string, []})
    |> map({String, :trim, []})
    |> unwrap_and_tag(:text)
    |> reduce({:build_struct, [Comment]})
    |> post_traverse({:filter_comment, []})

  section_name =
    repeat(
      choice([
        block_comment,
        utf8_string([not: ?=, not: ?-, not: ?[, not: ?\r, not: ?\n], min: 1),
        lookahead_not(comment) |> ascii_string([?-], min: 1),
        string("[")
      ])
    )

  section =
    ignore(times(string("="), min: 1))
    |> concat(section_name)
    |> ignore(repeat(string("=")))
    |> repeat(choice([ignore(whitespace), block_comment, comment]))
    |> lookahead(choice([newline, eos()]))
    |> post_traverse({:build_section, []})

  preparation =
    ignore(string("(") |> optional(whitespace))
    |> utf8_string([not: ?\), not: ?\r, not: ?\n], min: 1)
    |> ignore(string(")"))
    |> map({String, :trim, []})
    |> unwrap_and_tag(:preparation)

  quantity =
    ignore(optional(whitespace))
    |> utf8_string([not: ?%, not: ?}, not: ?\r, not: ?\n], min: 1)
    |> map({String, :trim, []})
    |> map({:parse_quantity, []})
    |> unwrap_and_tag(:quantity)

  unit =
    ignore(optional(whitespace))
    |> utf8_string([not: ?}, not: ?\r, not: ?\n], min: 1)
    |> map({String, :trim, []})
    |> unwrap_and_tag(:unit)

  amount =
    ignore(string("{"))
    |> optional(quantity |> optional(ignore(string("%")) |> optional(unit)))
    |> ignore(optional(whitespace) |> string("}"))

  duration =
    ignore(string("{"))
    |> concat(quantity)
    |> optional(ignore(string("%")) |> optional(unit))
    |> ignore(optional(whitespace) |> string("}"))

  multi_word_name =
    lookahead_not(utf8_char([?\s, ?\t]))
    |> utf8_string([not: ?{, not: ?@, not: ?#, not: ?~, not: ?\r, not: ?\n], min: 1)
    |> map({String, :trim_trailing, []})
    |> unwrap_and_tag(:name)

  non_word_chars =
    Enum.concat(0..0xD7FF, 0xE000..0x10FFFF)
    |> Enum.filter(&Regex.match?(~r/[\s\p{Zs}\p{P}~>+|=]/u, <<&1::utf8>>))
    |> Enum.reduce([], fn
      char, [first..last//1 | ranges] when char == last + 1 -> [first..char | ranges]
      char, ranges -> [char..char | ranges]
    end)
    |> Enum.map(&{:not, &1})

  defcombinatorp(
    :single_word_name,
    utf8_string(non_word_chars, min: 1)
    |> unwrap_and_tag(:name)
  )

  single_word_name = parsec(:single_word_name)

  optional_marker =
    string("?")
    |> replace({:optional, true})

  ingredient =
    ignore(string("@"))
    |> optional(optional_marker)
    |> choice([
      multi_word_name |> concat(amount),
      single_word_name |> optional(amount)
    ])
    |> optional(preparation)
    |> reduce({:build_ingredient, []})

  cookware =
    ignore(string("#"))
    |> optional(optional_marker)
    |> choice([
      multi_word_name |> concat(amount),
      single_word_name |> optional(amount)
    ])
    |> reduce({:build_struct, [Cookware]})

  timer =
    ignore(string("~"))
    |> choice([
      multi_word_name |> concat(duration),
      single_word_name |> optional(duration),
      duration
    ])
    |> reduce({:build_struct, [Timer]})

  line_break =
    string("\\")
    |> concat(newline)
    |> replace("\n")

  text =
    choice([
      utf8_string(
        [not: ?@, not: ?#, not: ?~, not: ?-, not: ?\\, not: ?[, not: ?\r, not: ?\n],
        min: 1
      ),
      string("@"),
      string("#"),
      string("~"),
      ascii_string([?-], min: 1),
      string("\\"),
      string("[")
    ])

  empty_line =
    repeat(choice([ignore(whitespace), comment, block_comment]))
    |> choice([ignore(newline), eos()])

  line_join =
    newline
    |> lookahead_not(choice([empty_line, string("=")]))
    |> replace(" ")

  note_line = ignore(optional(string(">") |> optional(whitespace))) |> concat(line_content)

  note =
    lookahead(string(">"))
    |> concat(note_line)
    |> repeat(line_join |> concat(note_line))
    |> reduce({Enum, :join, []})
    |> map({String, :trim, []})
    |> unwrap_and_tag(:text)
    |> reduce({:build_struct, [Note]})

  defcombinatorp(
    :inline,
    choice([
      comment,
      block_comment,
      ingredient,
      cookware,
      timer,
      line_break,
      text
    ])
  )

  inline = parsec(:inline)

  step =
    times(choice([inline, line_join]), min: 1)
    |> reduce({:merge_text, []})
    |> unwrap_and_tag(:fragments)
    |> reduce({:build_struct, [Step]})

  single_line_step =
    lookahead(string("="))
    |> times(inline, min: 1)
    |> reduce({:merge_text, []})
    |> unwrap_and_tag(:fragments)
    |> reduce({:build_struct, [Step]})

  defparsecp(
    :recipe,
    optional(metadata)
    |> repeat(lookahead_not(eos()) |> choice([section, single_line_step, note, empty_line, step]))
    |> eos()
    |> reduce({:build_recipe, []})
  )

  @doc """
  Parses a Cooklang recipe.

  ## Examples

      iex> CooklangParser.parse("Add @salt and @ground black pepper{1/2%tsp}.")
      {:ok,
       %CooklangParser.Recipe{
         sections: [
           %CooklangParser.Section{
             content: [
               %CooklangParser.Step{
                 fragments: [
                   "Add ",
                   %CooklangParser.Ingredient{name: "salt"},
                   " and ",
                   %CooklangParser.Ingredient{name: "ground black pepper", quantity: 0.5, unit: "tsp"},
                   "."
                 ]
               }
             ]
           }
         ]
       }}

      iex> {:ok, recipe} =
      ...>   CooklangParser.parse("Fry the @onion{1}(diced) in a #pan{} for ~{5%minutes}.")
      iex> [%CooklangParser.Section{content: [step]}] = recipe.sections
      iex> step.fragments
      [
        "Fry the ",
        %CooklangParser.Ingredient{name: "onion", quantity: 1, preparation: "diced"},
        " in a ",
        %CooklangParser.Cookware{name: "pan"},
        " for ",
        %CooklangParser.Timer{quantity: 5, unit: "minutes"},
        "."
      ]

      iex> {:ok, recipe} =
      ...>   CooklangParser.parse("---\\nservings: 2\\n---\\n= Sauce\\nSimmer.\\n\\n= Pasta\\nBoil.")
      iex> recipe.metadata
      %{"servings" => 2}
      iex> recipe.sections
      [
        %CooklangParser.Section{name: "Sauce", content: [%CooklangParser.Step{fragments: ["Simmer."]}]},
        %CooklangParser.Section{name: "Pasta", content: [%CooklangParser.Step{fragments: ["Boil."]}]}
      ]

      iex> {:ok, recipe} = CooklangParser.parse("Simmer. -- stir often", comments: true)
      iex> [%CooklangParser.Section{content: [step]}] = recipe.sections
      iex> step.fragments
      ["Simmer. ", %CooklangParser.Comment{text: "stir often"}]

      iex> CooklangParser.parse("---\\ntitle: [unclosed\\n---")
      {:error, "invalid YAML front matter: Unfinished flow collection"}

  ## Options

    * `:comments` - when `true`, keeps comments as `CooklangParser.Comment` structs.
      Defaults to `false`.
  """
  @spec parse(String.t(), keyword()) :: {:ok, Recipe.t()} | {:error, String.t()}
  def parse(source, opts \\ []) do
    case recipe(source, context: opts) do
      {:ok, [recipe], "", _context, _line, _offset} ->
        {:ok, recipe}

      {:error, reason, _rest, _context, _line, _offset} ->
        {:error, reason}
    end
  end

  defp filter_comment(rest, comment, %{comments: true} = context, _line, _offset),
    do: {rest, comment, context}

  defp filter_comment(rest, _comment, context, _line, _offset), do: {rest, [], context}

  defp merge_text([left, right | fragments]) when is_binary(left) and is_binary(right),
    do: merge_text([left <> right | fragments])

  defp merge_text([fragment | fragments]), do: [fragment | merge_text(fragments)]
  defp merge_text([]), do: []

  defp parse_yaml(rest, lines, context, _line, _offset) do
    yaml = lines |> Enum.reverse() |> Enum.join()

    case YamlElixir.read_from_string(yaml) do
      {:ok, metadata} when is_map(metadata) ->
        {rest, [metadata], context}

      {:ok, _other} ->
        {:error, "expected YAML front matter to be key-value pairs"}

      {:error, %YamlElixir.ParsingError{} = error} ->
        {:error, "invalid YAML front matter: #{error.message}"}
    end
  end

  defp build_section(rest, acc, context, _line, _offset) do
    {comments, name_parts} =
      acc |> Enum.reverse() |> Enum.split_with(&match?(%Comment{}, &1))

    name = name_parts |> Enum.join() |> String.trim()
    {rest, Enum.reverse([{:section, name} | comments]), context}
  end

  defp build_recipe([{:metadata, metadata} | items]),
    do: %Recipe{metadata: metadata, sections: group_sections(items)}

  defp build_recipe(items), do: %Recipe{sections: group_sections(items)}

  defp group_sections(items) do
    items
    |> Enum.chunk_while(%Section{}, &chunk_section/2, &{:cont, close_section(&1), nil})
    |> Enum.reject(&(&1 == %Section{}))
  end

  defp chunk_section({:section, name}, section),
    do: {:cont, close_section(section), %Section{name: name}}

  defp chunk_section(block, section),
    do: {:cont, %{section | content: [block | section.content]}}

  defp close_section(section), do: %{section | content: Enum.reverse(section.content)}

  defp build_struct(fields, module), do: struct!(module, fields)

  defp build_ingredient(fields) do
    ingredient = struct!(Ingredient, fields)

    case ingredient.name do
      # Cross reference to recipe as ingredient
      "./" <> path ->
        %{ingredient | name: Path.basename(path), reference: path}

      _name ->
        ingredient
    end
  end

  defp parse_quantity(string) do
    with :error <- parse_number(string),
         [_, numerator, denominator] <- Regex.run(~r{^([1-9]\d*)\s*/\s*(\d+)$}, string),
         denominator when denominator != 0 <- String.to_integer(denominator) do
      String.to_integer(numerator) / denominator
    else
      {:ok, number} -> number
      _ -> string
    end
  end

  defp parse_number(string) do
    case {Integer.parse(string), Float.parse(string)} do
      {{integer, ""}, _} -> {:ok, integer}
      {_, {float, ""}} -> {:ok, float}
      _ -> :error
    end
  end
end
