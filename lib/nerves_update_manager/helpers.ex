defmodule NervesUpdateManager.Helpers do
  @moduledoc false

  @semver_regex ~r"(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?"

  def get_version_from_release(release) do
    tag = Map.get(release, "tag_name")
    name = Map.get(release, "name")

    case parse_version(tag) do
      {:ok, version} -> version
      _ -> parse_version(name)
    end
  end

  defp parse_version(text) do
    with [version_string | _] <- Regex.run(@semver_regex, text),
         {:ok, version} <- Version.parse(version_string) do
      version
    else
      _ -> nil
    end
  end
end
