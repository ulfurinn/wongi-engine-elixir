defmodule Wongi.Engine.MixProject do
  use Mix.Project

  def project do
    [
      app: :wongi_engine,
      version: "0.9.4",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [
        plt_file: {:no_warn, "plts/dialyzer.plt"}
      ],
      name: "Wongi.Engine",
      description: "A pure-Elixir rule engine.",
      source_url: "https://github.com/ulfurinn/wongi-engine-elixir",
      docs: [
        logo: "./wongi.png"
      ],
      aliases: aliases(),
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:comparable, "~> 1.0.0"},
      # dev tools
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.3", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.27", only: :dev, runtime: false}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp aliases do
    [
      lint: [
        "format --check-formatted",
        "credo --strict",
        "dialyzer"
      ],
      "lint.ci": [
        "format --check-formatted",
        "credo --strict",
        "dialyzer --format github"
      ]
    ]
  end

  defp package do
    %{
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/ulfurinn/wongi-engine-elixir"
      }
    }
  end
end
