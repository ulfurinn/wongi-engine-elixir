defmodule WongiEngine.MixProject do
  use Mix.Project

  def project do
    [
      app: :wongi_engine,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      ulfnet_ref(Mix.env())
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  defp ulfnet_ref(:dev), do: {:ulfnet_ref, path: "../ulfnet_ref"}
  defp ulfnet_ref(:test), do: {:ulfnet_ref, path: "../ulfnet_ref"}
  defp ulfnet_ref(:prod), do: {:ulfnet_ref, "~> 0.1.0"}
end
