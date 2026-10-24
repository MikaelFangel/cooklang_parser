defmodule CooklangParserTest do
  use ExUnit.Case, async: true

  doctest CooklangParser

  # Canonical parser tests from https://github.com/cooklang/spec/blob/main/tests/canonical.yaml
  @canonical_path Path.join([__DIR__, "fixtures", "canonical.yaml"])
  @external_resource @canonical_path

  @defaults %{
    "ingredient" => %{"quantity" => "some", "units" => ""},
    "cookware" => %{"quantity" => 1, "units" => ""},
    "timer" => %{"name" => "", "quantity" => "", "units" => ""}
  }

  @skipped %{
    "testMetadataMultiwordKeyWithSpaces" => "conflicts with YAML front matter parsing"
  }

  describe "canonical" do
    for {name, %{"source" => source, "result" => result}} <-
          YamlElixir.read_from_file!(@canonical_path)["tests"] do
      @source source
      @expected result

      if reason = @skipped[name], do: @tag(skip: reason)

      test name do
        assert parse(@source) == normalize_expected(@expected)
      end
    end
  end

  defp parse(source) do
    {:ok, items} = CooklangParser.parse(source)

    steps =
      for {:step, step_items} <- items,
          step = normalize_step(step_items),
          step != [],
          do: step

    %{"steps" => steps, "metadata" => Keyword.get(items, :metadata, %{})}
  end

  defp normalize_step(items) do
    items
    |> Enum.reject(&match?({:comment, _}, &1))
    |> Enum.map(&normalize_item/1)
    |> merge_text()
  end

  defp normalize_item({:text, value}), do: %{"type" => "text", "value" => value}
  defp normalize_item({:line_break, value}), do: %{"type" => "text", "value" => value}

  defp normalize_item({type, fields}) when type in [:ingredient, :cookware, :timer] do
    item =
      for {key, value} <- fields, into: %{"type" => Atom.to_string(type)} do
        {canonical_key(key), value}
      end

    with_defaults(item)
  end

  defp canonical_key(:unit), do: "units"
  defp canonical_key(key), do: Atom.to_string(key)

  defp merge_text(items) do
    items
    |> Enum.chunk_by(&(&1["type"] == "text"))
    |> Enum.flat_map(fn
      [%{"type" => "text"} | _] = texts ->
        [%{"type" => "text", "value" => Enum.map_join(texts, & &1["value"])}]

      other ->
        other
    end)
  end

  defp normalize_expected(%{"steps" => steps, "metadata" => metadata}) do
    %{
      "steps" => Enum.map(steps, fn step -> Enum.map(step, &with_defaults/1) end),
      "metadata" => metadata
    }
  end

  defp with_defaults(%{"type" => type} = item) do
    item = Map.merge(Map.get(@defaults, type, %{}), item)

    if item["optional"] == false, do: Map.delete(item, "optional"), else: item
  end
end
