defmodule ProofOfReserves.MixProject do
  use Mix.Project

  def project do
    [
      app: :proof_of_reserves,
      version: "0.1.0",
      dialyzer: dialyzer(),
      test_coverage: [tool: ExCoveralls],
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      source_url: "https://github.com/RiverFinancial/proof-of-reserves",
      homepage_url: "https://river.com/reserves",
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
      {:math, "~> 0.6.0"}
    ] ++ dev_and_test_deps()
  end

  defp dev_and_test_deps do
    envs = [:dev, :test]

    [
      # Test & Lint
      {:credo, "== 1.6.4", only: envs, runtime: false},
      {:excoveralls, "== 0.14.5", only: envs},
      # Type checking
      {:dialyxir, "~> 1.4.3", only: envs, runtime: false},
      # Security
      {:sobelow, "~> 0.13.0", only: envs, runtime: false},
      {:mix_audit, "~> 2.1", only: envs, runtime: false},
      {:ex_doc, "~> 0.14", only: :dev, runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to create, migrate and run the seeds file at once:
  #
  #     $ mix ecto.setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      compile: [
        "compile #{unless System.get_env("DISABLE_WARNINGS_AS_ERRORS") do
          "--warnings-as-errors"
        end}"
      ]
    ]
  end

  defp dialyzer do
    [
      plt_file: {:no_warn, "plts/dialyzer.plt"},
      plt_add_apps: [:mix],
      flags: [:error_handling],
      ignore_warnings: ".dialyzer_ignore.exs"
    ]
  end

  defp package do
    [
      description: "River's Proof of Reserves library",
      licenses: ["MIT"],
      links: %{
        "River Proof of Reserves" => "https://river.com/reserves",
        "GitHub" => "https://github.com/RiverFinancial/proof-of-reserves"
      }
    ]
  end
end
