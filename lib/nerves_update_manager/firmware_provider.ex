defmodule NervesUpdateManager.FirmwareProvider do
  @moduledoc """
  The `FirmwareProvider` behavior allows you to use whatever means you like to host
  a new version of your firmware.  It has a single a callback, `c:download_request/2`,
  which instructs NervesUpdateManager where to download the firmware.
  """

  @doc """
  Given a `Version` and the system, return the `Req.Request` for the firmware.

  This allows you to add authentication headers and many other options.
  See `Req.Request.new/1` for a full list.

  The `system` argument will be whatever is reported by the call to `Nerves.Runtime.KV.get_active("nerves_fw_platform")`
  """
  @callback download_request(version :: Version.t(), system :: binary()) ::
              {:ok, Req.Request.t()}
              | {:error, any()}
end
