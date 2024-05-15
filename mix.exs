defmodule MixEdit.MixProject do
  use Mix.Project

  def project do
    [
      app: :mix_edit,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      description: "Elixir mix tasks to add, remove and update dependencies from mix.exs",
      package: package()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/thomas9911/mix_edit"}
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :hex]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:spitfire, git: "https://github.com/elixir-tools/spitfire.git"}
      # {:spitfire, path: "../spitfire"}
    ]
  end
end
