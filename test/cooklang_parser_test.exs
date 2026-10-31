defmodule CooklangParserTest do
  use ExUnit.Case, async: true

  alias CooklangParser.{Cookware, Ingredient, Recipe, Section, Step, Timer}

  doctest CooklangParser

  # Canonical parser tests from https://github.com/cooklang/spec/blob/main/tests/canonical.yaml
  @canonical_path Path.join([__DIR__, "fixtures", "canonical.yaml"])
  @external_resource @canonical_path

  @defaults %{
    "ingredient" => %{"quantity" => "some", "units" => ""},
    "cookware" => %{"quantity" => 1, "units" => ""},
    "timer" => %{"name" => "", "quantity" => "", "units" => ""}
  }

  @types %{Ingredient => "ingredient", Cookware => "cookware", Timer => "timer"}

  @skipped %{
    "testMetadataMultiwordKeyWithSpaces" => "conflicts with YAML front matter parsing",
    "testFractionsLike" => "leading zeros do not opt out of fraction parsing"
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
    {:ok, %Recipe{metadata: metadata, sections: sections}} = CooklangParser.parse(source)

    steps =
      for %Section{content: content} <- sections,
          %Step{fragments: fragments} <- content,
          do: normalize_step(fragments)

    %{"steps" => steps, "metadata" => metadata}
  end

  defp normalize_step(fragments), do: Enum.map(fragments, &normalize_fragment/1)

  defp normalize_fragment(text) when is_binary(text), do: %{"type" => "text", "value" => text}

  defp normalize_fragment(%module{} = fragment) when is_map_key(@types, module) do
    item =
      for {key, value} <- Map.from_struct(fragment),
          value != nil,
          into: %{"type" => @types[module]} do
        {canonical_key(key), value}
      end

    with_defaults(item)
  end

  defp canonical_key(:unit), do: "units"
  defp canonical_key(key), do: Atom.to_string(key)

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
