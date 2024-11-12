defmodule NervesUpdateManagerTest do
  use ExUnit.Case, async: false
  doctest NervesUpdateManager

  setup do
    data_directory = Application.get_env(:nerves_update_manager, :data_directory)

    Application.stop(:nerves_update_manager)

    dir =
      Path.join([data_directory, "NervesUpdateManager"])

    on_exit(fn ->
      File.rm_rf!(dir)
    end)

    :ok = Application.start(:nerves_update_manager)
  end

  describe "init/2" do
    test "sets initial status to :no_update_available" do
      assert NervesUpdateManager.status() == :no_update_available
    end

    test "raises error with invalid requirement" do
      requirement = Application.get_env(:nerves_update_manager, :requirement)
      Application.put_env(:nerves_update_manager, :requirement, "INVALID")

      on_exit(fn ->
        Application.put_env(:nerves_update_manager, :requirement, requirement)
      end)

      assert_raise ArgumentError, fn -> NervesUpdateManager.init([]) end
    end
  end

  describe "subscribe/0" do
    test "broadcasts status update messages" do
      # Arrange
      NervesUpdateManager.subscribe()

      # Act
      NervesUpdateManager.check_for_updates()

      # Assert
      assert_receive {NervesUpdateManager, :checking_for_updates}
    end
  end

  describe "unsubscribe/0" do
    test "removes process from subscriptions" do
      # Arrange
      NervesUpdateManager.subscribe()

      # Act
      NervesUpdateManager.unsubscribe()

      # Assert
      NervesUpdateManager.check_for_updates()
      refute_receive {NervesUpdateManager, :checking_for_updates}
    end
  end

  describe "check_for_updates/0" do
    test "returns busy when it's downloading" do
      # Arrange

      Application.put_env(
        :nerves_update_manager,
        :test_firmware_url,
        "http://ipv4.download.thinkbroadband.com/100MB.zip"
      )

      NervesUpdateManager.download_update(Version.parse!("0.10.0"))

      # Act
      result = NervesUpdateManager.check_for_updates()

      # Assert
      assert :busy == result
    end
  end

  describe "download_update/0" do
    test "downloads the available update" do
      # Arrange
      current_version =
        Nerves.Runtime.KV.get_active("nerves_fw_version")
        |> Version.parse!()

      next_version = %{current_version | patch: current_version.patch + 1}
      Application.put_env(:nerves_update_manager, :test_latest_version, next_version)
      NervesUpdateManager.check_for_updates()
      NervesUpdateManager.subscribe()

      # Act
      result = NervesUpdateManager.download_update()

      # Assert
      assert :ok == result
      assert_receive {NervesUpdateManager, :starting_download}
    end

    test "returns an error when no updates are available" do
      # Arrange
      Application.put_env(:nerves_update_manager, :test_latest_version, "0.10.0")
      NervesUpdateManager.check_for_updates()

      # Act
      result = NervesUpdateManager.download_update()

      # Assert
      assert {:error, _} = result
    end

    test "returns an error while already downloading" do
      # Arrange
      Application.put_env(
        :nerves_update_manager,
        :test_firmware_url,
        "http://ipv4.download.thinkbroadband.com/100MB.zip"
      )

      NervesUpdateManager.download_update(Version.parse!("0.10.0"))

      # Act
      result = NervesUpdateManager.download_update()

      # Assert
      assert {:error, _} = result
    end
  end

  describe "download_update/1" do
    test "downloads firware with the given version" do
      # Arrange
      NervesUpdateManager.subscribe()

      Application.put_env(
        :nerves_update_manager,
        :test_firmware_url,
        "http://ipv4.download.thinkbroadband.com/5MB.zip"
      )

      version = Version.parse!("1.0.0")
      system = Nerves.Runtime.KV.get_active("nerves_fw_platform")
      data_directory = Application.get_env(:nerves_update_manager, :data_directory)

      firmware_path =
        Path.join([
          data_directory,
          "NervesUpdateManager",
          system,
          "#{Version.to_string(version)}.fw"
        ])

      # Act
      NervesUpdateManager.download_update(version)

      # Assert
      assert_receive {NervesUpdateManager, {:update_ready, ^version}}, 10_000

      assert File.exists?(firmware_path)
    end
  end
end
