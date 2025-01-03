defmodule Yarnballs.MixProject do
  use Mix.Project

  def project do
    [
      app: :yarnballs,
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
      {:jason, "~> 1.0"},
      {:rustler, "~> 0.35"},
      # dev
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false}
    ]
  end
end
