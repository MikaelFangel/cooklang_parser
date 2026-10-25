defmodule CooklangParser.MixProject do
  use Mix.Project

  @version "0.1.1"
  @source_url "https://github.com/MikaelFangel/cooklang_parser"

  def project do
    [
      app: :cooklang_parser,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      description: description(),
      package: package(),
      deps: deps(),
      docs: docs(),
      source_url: @source_url,
      homepage_url: @source_url
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false, warn_if_outdated: true},
      {:mix_audit, "~> 2.1", only: [:dev, :test], runtime: false},
      {:nimble_parsec, "~> 1.4"},
      {:yaml_elixir, "~> 2.11"}
    ]
  end

  defp description do
    """
    A Cooklang parser for Elixir.
    """
  end

  defp package do
    [
      name: "cooklang_parser",
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Documentation" => "https://hexdocs.pm/cooklang_parser"
      },
      maintainers: ["Mikael Fangel"],
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE)
    ]
  end

  defp docs do
    [
      main: "readme",
      source_url: @source_url,
      source_ref: "v#{@version}",
      extras: ["README.md", "LICENSE"]
    ]
  end
end
