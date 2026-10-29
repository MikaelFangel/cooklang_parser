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
    {:cooklang_parser, "~> 0.4.0"}
  ]
end
```

## Usage

The examples below use these aliases:

```elixir
alias CooklangParser.{Comment, Ingredient, Recipe, Section, Step}
```

```elixir
CooklangParser.parse("Add @salt and @ground black pepper{1/2%tsp}.")
{:ok,
 %Recipe{
   sections: [
     %Section{
       content: [
         %Step{
           fragments: [
             "Add ",
             %Ingredient{name: "salt"},
             " and ",
             %Ingredient{name: "ground black pepper", quantity: 0.5, unit: "tsp"},
             "."
           ]
         }
       ]
     }
   ]
 }}
```

Comments are excluded from the output by default. Pass `comments: true` to keep them:

```elixir
CooklangParser.parse("Simmer. -- stir often")
{:ok, %Recipe{sections: [%Section{content: [%Step{fragments: ["Simmer. "]}]}]}}

CooklangParser.parse("Simmer. -- stir often", comments: true)
{:ok,
 %Recipe{
   sections: [
     %Section{
       content: [%Step{fragments: ["Simmer. ", %Comment{text: "stir often"}]}]
     }
   ]
 }}
```

## AST

`CooklangParser.parse/2` returns the recipe as a tree of structs:

```
Recipe
├── metadata: map from the YAML front matter
└── sections: [Section]
    └── content: [Step | Note | Comment]
        └── fragments: [String | Ingredient | Cookware | Timer | Comment]
```

## Spec

Implements the [Cooklang spec](https://cooklang.org/docs/spec/) and is tested against its
[canonical tests](https://github.com/cooklang/spec/blob/main/tests/canonical.yaml).

The parser has minor variations from the spec, such as support for including comments in the output.
Where the spec is unclear, the parser tries to follow the behaviour of [cooklang-rs](https://github.com/cooklang/cooklang-rs).
