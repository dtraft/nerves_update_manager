defmodule NervesUpdateManager.VersionProvider.GithubReleaseTest do
  use ExUnit.Case, async: true

  defmodule TestVersionProvider do
    use NervesUpdateManager.VersionProvider.GithubRelease, owner: "Reflect-OS", repo: "firmware"
  end

  describe "compile time checks" do
    test "owner option is provided" do
      assert_raise ArgumentError, "owner option must be provided.", fn ->
        defmodule FailingVersionProvider do
          use NervesUpdateManager.VersionProvider.GithubRelease, repo: "firmware"
        end
      end
    end

    test "repo option is provided" do
      assert_raise ArgumentError, "repo option must be provided.", fn ->
        defmodule FailingVersionProvider do
          use NervesUpdateManager.VersionProvider.GithubRelease, owner: "Reflect-OS"
        end
      end
    end
  end

  describe "get_latest_matching_version/1" do
    test "returns the correct firmware url" do
      # Arrange
      version = Version.parse!("0.10.0")

      # Act
      result = TestVersionProvider.get_latest_matching_version("> 0.9.0 and < 0.10.1")

      # Assert
      assert {:ok, ^version} = result
    end

    test "returns an error when version matching requirement is found" do
      # Arrange
      requirement = "< 0.9.0"

      # Act
      result = TestVersionProvider.get_latest_matching_version(requirement)

      # Assert
      assert {:error, _} = result
    end

    test "returns an error when the API call fails" do
      # Arrange
      defmodule APICallFailureVersionProvider do
        use NervesUpdateManager.VersionProvider.GithubRelease,
          owner: "Reflect-OS",
          repo: "invalid"
      end

      # Act
      result = APICallFailureVersionProvider.get_latest_matching_version("~> 0.10.0")

      # Assert
      assert {:error, "Error fetching version" <> _rest} = result
    end
  end
end
