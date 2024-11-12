defmodule TestProvider do
  @behaviour NervesUpdateManager.VersionProvider
  @behaviour NervesUpdateManager.FirmwareProvider

  def get_latest_matching_version(_requirement) do
    version =
      Application.get_env(:nerves_update_manager, :test_latest_version, Version.parse!("0.2.0"))

    {:ok, version}
  end

  def download_request(_version, _system) do
    url = Application.get_env(:nerves_update_manager, :test_firmware_url, "http://test.com")
    {:ok, Req.new(url: url)}
  end
end
