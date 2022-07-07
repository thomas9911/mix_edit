defmodule Example.MixProject do
  use Mix.Project

  # more comments

  def project do
    [
      app: :example,
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
      # mix_add is the only required deps (here)
      {:mix_add, path: "../../"},
      {:jason, "~> 1.3.0"}
    ]
  end
end
