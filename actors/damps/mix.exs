defmodule Damps.MixProject do
  use Mix.Project

  @app_name :damps
  @version "0.1.0"

  def project do
    [
      app: @app_name,
      version: @version,
      elixir: "~> 1.10",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),

      # Releases
      releases: releases(),

      # Testing
      test_coverage: [
        tool: ExCoveralls
      ],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],

      # Dialyzer
      dialyzer: dialyzer()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp release_version(nil), do: @version
  defp release_version(suffix), do: @version <> "-" <> suffix

  defp copy_extra_files(rel) do
    File.copy!(
      "config/prod.exs",
      "#{rel.path}/releases/#{release_version(System.get_env("RELEASE_TAR_NAME_SUFFIX"))}/releases.exs"
    )

    rel
  end

  defp releases() do
    [
      {@app_name,
       [
         version: release_version(System.get_env("RELEASE_TAR_NAME_SUFFIX")),
         steps: [:assemble, &copy_extra_files/1, :tar],
         # Defaults to "_build/MIX_ENV/rel/RELEASE_NAME"
         path: "#{System.get_env("MIX_RELEASE_PATH", "_build")}/#{to_string(@app_name)}",
         include_executables_for: [:unix],
         applications: [
           runtime_tools: :permanent,
           mnesia: :permanent
         ]
       ]}
    ]
  end

  # mix dialyzer --format short
  defp dialyzer do
    [
      plt_add_apps: [:mix, :eex, :ex_unit],
      ignore_warnings: ".dialyzer_ignore.exs",
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
      flags: [
        :unmatched_returns,
        :error_handling,
        :race_conditions,
        :no_opaque,
        :unknown,
        :no_return
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:norm, "~> 0.12.0"},

      # Test
      {:excoveralls, "~> 0.13", only: :test},

      # Code Analysis
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.4", only: [:dev, :test]},
      {:mox, "~> 0.5.2", only: [:dev, :test]}
    ]
  end
end
