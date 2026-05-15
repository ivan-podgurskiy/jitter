defmodule Jitter.MixProject do
  use Mix.Project

  def project do
    [
      app: :jitter,
      version: "0.1.0",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Hex
      description: description(),
      package: package(),

      # Docs
      name: "Jitter",
      source_url: "https://github.com/ivan-podgurskiy/jitter",
      docs: docs()
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
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp description do
    "Backoff jitter strategies (No, Full, Equal, Decorrelated) from " <>
      "Marc Brooker's Exponential Backoff and Jitter, as composable Stream transformers."
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => "https://github.com/ivan-podgurskiy/jitter"
      }
    ]
  end

  defp docs do
    [
      main: "Jitter",
      extras: ["README.md", "CHANGELOG.md"]
    ]
  end
end
