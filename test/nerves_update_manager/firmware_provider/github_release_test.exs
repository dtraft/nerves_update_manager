defmodule NervesUpdateManager.FirmwareProvider.GithubReleaseTest do
  use ExUnit.Case, async: true

  defmodule TestFirmwareProvider do
    use NervesUpdateManager.FirmwareProvider.GithubRelease, owner: "Reflect-OS", repo: "firmware"
  end

  describe "compile time checks" do
    test "owner option is provided" do
      assert_raise ArgumentError, "owner option must be provided.", fn ->
        defmodule FailingFirmwareProvider do
          use NervesUpdateManager.FirmwareProvider.GithubRelease, repo: "firmware"
        end
      end
    end

    test "repo option is provided" do
      assert_raise ArgumentError, "repo option must be provided.", fn ->
        defmodule FailingFirmwareProvider do
          use NervesUpdateManager.FirmwareProvider.GithubRelease, owner: "Reflect-OS"
        end
      end
    end
  end

  describe "download_request/2" do
    test "returns the correct firmware url" do
      # Arrange
      version = Version.parse!("0.10.0")

      # Act
      result = TestFirmwareProvider.download_request(version, "rpi3")

      # Assert
      expected_url =
        "https://github.com/Reflect-OS/firmware/releases/download/v0.10.0/ReflectOS-firmware-rpi3.fw"
        |> URI.parse()

      assert {:ok, %Req.Request{url: ^expected_url}} = result
    end

    test "returns an error when no supported firmware found for the system" do
      # Arrange
      version = Version.parse!("0.10.0")

      # Act
      result = TestFirmwareProvider.download_request(version, "invalid")

      # Assert
      assert {:error, _} = result
    end

    test "returns an error when the release doesn't exist" do
      # Arrange
      version = Version.parse!("0.1.0")

      # Act
      result = TestFirmwareProvider.download_request(version, "rpi3")

      # Assert
      assert {:error, _} = result
    end

    test "returns an error when the API call fails" do
      # Arrange
      defmodule APICallFailureFirmwareProvider do
        use NervesUpdateManager.FirmwareProvider.GithubRelease,
          owner: "Reflect-OS",
          repo: "invalid"
      end

      version = Version.parse!("0.1.0")

      # Act
      result = APICallFailureFirmwareProvider.download_request(version, "rpi3")

      # Assert
      assert {:error, "Error determing firmware" <> _rest} = result
    end
  end
end
