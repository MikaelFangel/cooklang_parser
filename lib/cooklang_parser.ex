defmodule CooklangParser do
  @moduledoc """
  Implementation of the Cooklang spec.
  """
  import NimbleParsec

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
    |> unwrap_and_tag(:comment)
    |> post_traverse({:filter_comment, []})

  block_comment =
    ignore(string("[-"))
    |> repeat(lookahead_not(string("-]")) |> choice([newline, utf8_char(not: ?\r)]))
    |> ignore(string("-]"))
    |> reduce({List, :to_string, []})
    |> map({String, :trim, []})
    |> unwrap_and_tag(:comment)
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
    |> tag(:ingredient)
    |> map({:resolve_reference, []})

  cookware =
    ignore(string("#"))
    |> optional(optional_marker)
    |> choice([
      multi_word_name |> concat(amount),
      single_word_name |> optional(amount)
    ])
    |> tag(:cookware)

  timer =
    ignore(string("~"))
    |> choice([
      multi_word_name |> concat(duration),
      single_word_name |> optional(duration),
      duration
    ])
    |> tag(:timer)

  line_break =
    string("\\")
    |> concat(newline)
    |> replace("\n")
    |> unwrap_and_tag(:text)

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
    |> unwrap_and_tag(:text)

  empty_line =
    repeat(choice([ignore(whitespace), comment, block_comment]))
    |> choice([ignore(newline), eos()])

  line_join =
    newline
    |> lookahead_not(choice([empty_line, string("=")]))
    |> replace(" ")

  soft_newline = line_join |> unwrap_and_tag(:text)

  note_line = ignore(optional(string(">") |> optional(whitespace))) |> concat(line_content)

  note =
    lookahead(string(">"))
    |> concat(note_line)
    |> repeat(line_join |> concat(note_line))
    |> reduce({Enum, :join, []})
    |> map({String, :trim, []})
    |> unwrap_and_tag(:note)

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
    times(choice([inline, soft_newline]), min: 1)
    |> reduce({:merge_text, []})
    |> unwrap_and_tag(:step)

  single_line_step =
    lookahead(string("="))
    |> times(inline, min: 1)
    |> reduce({:merge_text, []})
    |> unwrap_and_tag(:step)

  defparsecp(
    :recipe,
    optional(metadata)
    |> repeat(lookahead_not(eos()) |> choice([section, single_line_step, note, empty_line, step]))
    |> eos()
  )

  @doc """
  Parses a Cooklang recipe.

  ## Examples

      iex> CooklangParser.parse("Add @salt and @ground black pepper{1/2%tsp}.")
      {:ok,
       [
         step: [
           text: "Add ",
           ingredient: [name: "salt"],
           text: " and ",
           ingredient: [name: "ground black pepper", quantity: 0.5, unit: "tsp"],
           text: "."
         ]
       ]}

      iex> CooklangParser.parse("Fry the @onion{1}(diced) in a #pan{} for ~{5%minutes}.")
      {:ok,
       [
         step: [
           text: "Fry the ",
           ingredient: [name: "onion", quantity: 1, preparation: "diced"],
           text: " in a ",
           cookware: [name: "pan"],
           text: " for ",
           timer: [quantity: 5, unit: "minutes"],
           text: "."
         ]
       ]}

      iex> CooklangParser.parse("---\\nservings: 2\\n---\\n= Sauce\\nSimmer. -- stir often")
      {:ok,
       [
         metadata: %{"servings" => 2},
         section: "Sauce",
         step: [text: "Simmer. "]
       ]}

      iex> CooklangParser.parse("Simmer. -- stir often", comments: true)
      {:ok, [step: [text: "Simmer. ", comment: "stir often"]]}

      iex> CooklangParser.parse("---\\ntitle: [unclosed\\n---")
      {:error, "invalid YAML front matter: Unfinished flow collection"}

  ## Options

    * `:comments` - when `true`, keeps comments as `{:comment, text}` items.
      Defaults to `false`.
  """
  @spec parse(String.t(), keyword()) :: {:ok, keyword()} | {:error, String.t()}
  def parse(source, opts \\ []) do
    case recipe(source, context: opts) do
      {:ok, items, "", _context, _line, _offset} ->
        {:ok, items}

      {:error, reason, _rest, _context, _line, _offset} ->
        {:error, reason}
    end
  end

  defp filter_comment(rest, comment, %{comments: true} = context, _line, _offset),
    do: {rest, comment, context}

  defp filter_comment(rest, _comment, context, _line, _offset), do: {rest, [], context}

  defp merge_text([{:text, left}, {:text, right} | items]),
    do: merge_text([{:text, left <> right} | items])

  defp merge_text([item | items]), do: [item | merge_text(items)]
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
      acc |> Enum.reverse() |> Enum.split_with(&match?({:comment, _}, &1))

    name = name_parts |> Enum.join() |> String.trim()
    {rest, Enum.reverse([{:section, name} | comments]), context}
  end

  defp resolve_reference({:ingredient, fields} = ingredient) do
    case Keyword.fetch!(fields, :name) do
      "./" <> path ->
        name = path |> String.split("/") |> List.last()
        {:ingredient, Keyword.replace!(fields, :name, name) ++ [reference: path]}

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
