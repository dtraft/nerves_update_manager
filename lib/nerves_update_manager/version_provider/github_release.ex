defmodule NervesUpdateManager.VersionProvider.GithubRelease do
  alias NervesUpdateManager.Helpers

  defmacro __using__(opts) do
    owner =
      case Keyword.fetch(opts, :owner) do
        {:ok, owner} -> owner
        _ -> raise ArgumentError, "owner option must be provided."
      end

    repo =
      case Keyword.fetch(opts, :repo) do
        {:ok, repo} -> repo
        _ -> raise ArgumentError, "repo option must be provided."
      end

    quote do
      @behaviour NervesUpdateManager.VersionProvider

      @impl true
      def get_latest_matching_version(requirement) do
        unquote(__MODULE__).get_latest_matching_version_from_github(
          unquote(owner),
          unquote(repo),
          requirement
        )
      end
    end
  end

  def get_latest_matching_version_from_github(owner, repo, requirement) do
    case Tentacat.Releases.list(owner, repo) do
      {200, releases, _} ->
        latest_matching =
          releases
          |> Enum.map(&Helpers.get_version_from_release/1)
          |> Enum.filter(fn v -> !is_nil(v) end)
          |> Enum.sort(Version)
          |> Enum.find(fn v -> Version.match?(v, requirement) end)

        if !is_nil(latest_matching) do
          {:ok, latest_matching}
        else
          {:error, "Unable to find a matching version"}
        end

      {code, body, _} ->
        {:error,
         "Error fetching version, got status code: #{code} with response: #{inspect(body)}"}

      _ ->
        {:error, "Unexpected response from github release list api"}
    end
  end
end
