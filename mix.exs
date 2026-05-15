defmodule Jitter.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/ivan-podgurskiy/jitter"

  def project do
    [
      app: :jitter,
      version: @version,
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Hex
      description: description(),
      package: package(),

      # Docs
      name: "Jitter",
      source_url: @source_url,
      docs: docs(),

      # Dialyzer
      dialyzer: [
        plt_add_apps: [:ex_unit, :mix],
        plt_local_path: "priv/plts/local.plt",
        plt_core_path: "priv/plts/core.plt"
      ]
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
      {:stream_data, "~> 1.0", only: [:dev, :test]},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end

  defp description do
    "Backoff jitter strategies (No, Full, Equal, Decorrelated) from " <>
      "Marc Brooker's Exponential Backoff and Jitter, as composable Stream transformers."
  end

  defp package do
    [
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md),
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      main: "Jitter",
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: ["README.md", "CHANGELOG.md"]
    ]
  end
end
