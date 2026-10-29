# CooklangParser

A Cooklang parser written in Elixir without any NIF bindings.

## What is Cooklang?

Cooklang is a markup language for writing recipes and meal plans in plain text files.
This frees you from the need for applications and databases to read your recipes and meal plans, though they can still make it more convenient.

### Example

```cooklang
Whisk @eggs{2} with @milk{2%tbsp} in a #bowl.
Cook in a #frying pan{} with @butter{10%g} for ~{3%minutes}.
```

## Getting started

```elixir
def deps do
  [
    {:cooklang_parser, "~> 0.3.0"}
  ]
end
```

## Usage

```elixir
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
```

Comments are excluded from the output by default. Pass `comments: true` to keep them:

```elixir
iex> CooklangParser.parse("Simmer. -- stir often")
{:ok, [step: [text: "Simmer. "]]}

iex> CooklangParser.parse("Simmer. -- stir often", comments: true)
{:ok, [step: [text: "Simmer. ", comment: "stir often"]]}
```

## Spec

Implements the [Cooklang spec](https://cooklang.org/docs/spec/) and is tested against its
[canonical tests](https://github.com/cooklang/spec/blob/main/tests/canonical.yaml).

The parser has minor variations from the spec, such as support for including comments in the output.
Where the spec is unclear, the parser tries to follow the behaviour of [cooklang-rs](https://github.com/cooklang/cooklang-rs).
