# CooklangParser

Cooklang parser in Elixir using nimbleparsec.

## Installation

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

## Spec

Implements the [Cooklang spec](https://cooklang.org/docs/spec/) and is tested against its
[canonical tests](https://github.com/cooklang/spec/blob/main/tests/canonical.yaml).
