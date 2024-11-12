defmodule NervesUpdateManager.MixProject do
  use Mix.Project

  @version Path.join(__DIR__, "VERSION")
           |> File.read!()
           |> String.trim()

  @source_url "https://github.com/dtraft/nerves_update_manager"

  def project do
    [
      app: :nerves_update_manager,
      version: @version,
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      description: description(),
      deps: deps(),
      deps: deps(),
      docs: docs(),
      package: package(),
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {NervesUpdateManager.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:nerves_runtime, "~> 0.13.7"},
      {:nerves_firmware, "~> 0.4.0"},
      {:req, "~> 0.5.0"},
      {:tentacat, "~> 2.0"},
      # Used to run test endpoints for checking for updates
      {:test_server, "~> 0.1", only: [:test]}
    ]
  end

  defp description do
    """
    Nerves Update Manager allows nerves systems to update themselves
    with the latest firmware.
    """
  end

  defp package do
    [
      files: package_files(),
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      name: "Nerves Update Manager",
      source_url: @source_url,
      homepage_url: @source_url,
      source_ref: "v#{@version}",
      extras: ["README.md"],
      main: "readme"
    ]
  end

  defp package_files,
    do: [
      "lib",
      ".formatter.exs",
      "CHANGELOG.md",
      "LICENSE",
      "mix.exs",
      "README.md",
      "VERSION"
    ]

  defp elixirc_paths(:test), do: ["test/support", "lib"]
  defp elixirc_paths(_), do: ["lib"]
end
