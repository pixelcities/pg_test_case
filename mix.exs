defmodule PgTestCase.MixProject do
  use Mix.Project

  def project do
    [
      app: :pg_test_case,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      name: "PgTestCase",
      description: description(),
      package: package(),
      source_url: "https://github.com/pixelcities/pg_test_case"
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ecto_sql, "~> 3.0"},
      {:ex_doc, "~> 0.27", only: :dev, runtime: false},
    ]
  end

  defp description() do
    """
    A small utility to create a temporary postgres server for your tests
    """
  end

  defp package() do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/pixelcities/pg_test_case"}
    ]
  end
end
