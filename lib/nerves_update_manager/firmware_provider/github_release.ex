defmodule NervesUpdateManager.FirmwareProvider.GithubRelease do
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
      @behaviour NervesUpdateManager.FirmwareProvider

      @impl true
      def download_request(version, system) do
        unquote(__MODULE__).get_firmware_for_version(
          unquote(owner),
          unquote(repo),
          version,
          system
        )
      end
    end
  end

  def get_firmware_for_version(owner, repo, version, system) do
    case Tentacat.Releases.list(owner, repo) do
      {200, releases, _} ->
        release =
          releases
          |> Enum.find(fn release ->
            version == Helpers.get_version_from_release(release)
          end)

        if !is_nil(release) do
          system_regex =
            system
            |> Regex.escape()
            |> Kernel.<>("[^\\w\\d]")
            |> Regex.compile!()

          asset =
            release["assets"]
            |> Enum.find(fn asset ->
              name = asset["name"]
              String.ends_with?(name, ".fw") && Regex.match?(system_regex, name)
            end)

          if !is_nil(asset) do
            {:ok, Req.new(url: asset["browser_download_url"], method: :get)}
          else
            {:error, "No asset found for release #{release["name"]} for system #{system}"}
          end
        else
          {:error, "Unable to find a release for version: #{version}"}
        end

      {code, body, _} ->
        {:error,
         "Error determing firmware, got status code: #{code} with response: #{inspect(body)}"}

      _ ->
        {:error, "Unexpected response from github release list api"}
    end
  end
end
