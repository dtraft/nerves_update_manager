defmodule NervesUpdateManager do
  require Logger
  use GenServer

  @firmware_provider Application.compile_env(
                       :nerves_update_manager,
                       :firmware_provider
                     )

  @version_provider Application.compile_env(
                      :nerves_update_manager,
                      :version_provider
                    )

  @process_name NervesUpdateManager

  @registry NervesUpdateManagerSubscriptions

  @channel "subscriptions"

  # Client API
  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: @process_name)
  end

  @doc """
  Retrieves the current update status.
  """
  @spec status() ::
          :no_update_available
          | :checking_for_updates
          | {:update_available, version :: Version.t()}
          | :starting_download
          | {:downloading, progress :: float() | :unknown}
          | {:update_ready, version :: binary()}
          | {:error, reason :: any()}

  def status() do
    GenServer.call(@process_name, :get_status)
  end

  @doc """

  """
  @spec subscribe() :: :ok
  def subscribe() do
    {:ok, _} = Registry.register(@registry, @channel, [])
    :ok
  end

  @doc """

  """
  @spec unsubscribe() :: :ok
  def unsubscribe() do
    Registry.unregister(@registry, @channel)

    :ok
  end

  @doc """
  Initiates a check for updates using the configured `NervesUpdateManager.VersionProvider`
  """
  @spec check_for_updates() :: :ok | :busy
  def check_for_updates() do
    case status() do
      {:downloading, _} ->
        :busy

      _ ->
        GenServer.cast(@process_name, :check_for_updates)
    end
  end

  @doc """
  If an update is available, downloads it using the `Req.Request` from the `NervesUpdateManager.FirmwareProvider`.
  """
  @spec download_update() :: :ok | {:error, reason :: any()}
  def download_update() do
    case status() do
      {:update_available, version} ->
        download_update(version)

      :no_update_available ->
        {:error, "No update available"}

      status ->
        {:error, "Busy, current status: #{inspect(status)}"}
    end
  end

  @doc """
  Downloads a firmware update with the given version using the `Req.Request` from the `NervesUpdateManager.FirmwareProvider`
  """
  @spec download_update(Version.t()) :: :ok
  def download_update(%Version{} = version) do
    GenServer.cast(@process_name, {:download_firmware, version})
  end

  @doc """
  Applies a previously downloaded firmware update.

  Note that this function checks if `Nerves.Firmware.allow_upgrade?/0` is true and
  that the current status is `{:update_ready, version}`.

  If either condition fails, an error will be returned.

  By default, this method reboots the system.  You can disable that by passing in
  the `reboot: false` option, e.g. `NervesUpdateManager.update_firmware(reboot: false)`.
  """
  @spec update_firmware(opts :: Keyword.t()) ::
          :ok
          | {:error, reason :: binary()}
  def update_firmware(opts \\ []) do
    opts = Keyword.put_new(opts, :reboot, true)

    case {status(), Nerves.Firmware.allow_upgrade?()} do
      {{:update_ready, version}, true} ->
        firmware_path = get_firmware_file_path(version)

        case Nerves.Firmware.upgrade_and_finalize(firmware_path) do
          :ok ->
            Logger.debug("[NervesUpdateManager] Successfully applied update to #{version}")

            if opts[:reboot] do
              Logger.debug("[NervesUpdateManager] Rebooting.")
              Nerves.Firmware.reboot()
            end

            :ok
        end

      {_, false} ->
        {:error, "Update not allowed at this time due to a pending update."}

      {status, _} ->
        {:error, "Not ready for update, status: #{inspect(status)}"}
    end
  end

  # Server API
  @impl true
  def init(_opts) do
    requirement_string = Application.get_env(:nerves_update_manager, :requirement)

    requirement =
      case Version.parse_requirement(requirement_string) do
        {:ok, requirement} ->
          requirement

        _ ->
          raise ArgumentError, """
            You must must provide a valid requirement string, got: #{requirement_string}"
          """
      end

    initial_state = %{
      requirement: requirement,
      status: :no_update_available
    }

    {:ok, initial_state}
  end

  @impl true
  def handle_call(:get_status, _from, %{status: status} = state), do: {:reply, status, state}

  @doc false
  @impl true
  def handle_cast(:check_for_updates, %{requirement: requirement} = state) do
    state = set_status(state, :checking_for_updates)

    latest_downloaded_version = get_latest_downloaded_version()

    case check_for_updates(requirement) do
      {:update_available, version} when version > latest_downloaded_version ->
        Logger.debug("[NervesUpdateManager] Update available, version: #{version}")
        {:noreply, set_status(state, {:update_available, version})}

      {:update_available, version} ->
        Logger.debug(
          "[NervesUpdateManager] Latest update already downloaded, version: #{version}"
        )

        {:noreply, set_status(state, :no_update_available)}

      :no_matching_version ->
        Logger.debug(
          "[NervesUpdateManager] No version found matching requirement: #{requirement}"
        )

        {:noreply, set_status(state, :no_update_available)}

      :no_update_available ->
        Logger.debug("[NervesUpdateManager] No available updates")
        {:noreply, set_status(state, :no_update_available)}

      {:error, error} ->
        Logger.error(
          "[NervesUpdateManager] Error getting latest matching version: #{inspect(error)}"
        )

        {:noreply, set_status(state, {:error, error})}
    end
  end

  @doc false
  @impl true
  def handle_cast({:download_firmware, version}, state) do
    file_path = get_firmware_file_path(version)

    state =
      if File.exists?(file_path) do
        set_status(state, {:update_ready, version})
      else
        download_firmware(file_path, version, state)
      end

    {:noreply, state}
  end

  @impl true
  def handle_info(
        {{Finch.HTTP1.Pool, _pid}, {:data, data}},
        %{
          download: {complete, total, file_pid},
          status: {:downloading, previous_progress}
        } = state
      ) do
    IO.binwrite(file_pid, data)
    chunk_size = byte_size(data)
    complete = complete + chunk_size

    progress =
      if total > 0 do
        complete / total
      else
        :unknown
      end

    state =
      state
      |> Map.put(:download, {complete, total, file_pid})

    # Chuck size is pretty small, so this helps create noise for
    # subscribers
    state =
      if progress - previous_progress > 0.05 do
        set_status(state, {:downloading, progress})
      else
        state
      end

    {:noreply, state}
  end

  def handle_info(
        {{Finch.HTTP1.Pool, _pid}, :done},
        %{
          download: {_, _, file_pid}
        } = state
      ) do
    File.close(file_pid)

    state =
      state
      |> is_update_ready()

    {:noreply, state}
  end

  # Helpers
  defp download_firmware(file_path, version, state) do
    system = Nerves.Runtime.KV.get_active("nerves_fw_platform")

    state = set_status(state, :starting_download)

    case File.open(file_path, [:write, :binary]) do
      {:ok, file_pid} ->
        with {:ok, req} <- @firmware_provider.download_request(version, system),
             {:ok, size} <- get_firmware_size(req),
             {:ok, _resp} <- Req.request(req, into: :self, raw: true) do
          state =
            state
            |> Map.put(:download, {0, size, file_pid})

          set_status(state, {:downloading, 0})
        else
          {:error, error} ->
            Logger.error(
              "[NervesUpdateManager] Error downloading firmware for version: #{version}.  Error: #{inspect(error)}"
            )

            set_status(state, {:error, error})
        end

      {:error, reason} ->
        Logger.error("Unable to open file: #{file_path}.  Error: #{inspect(reason)}")
        set_status(state, {:error, reason})
    end
  end

  defp is_update_ready(state) do
    current_version = get_current_version()

    latest_version = get_latest_downloaded_version()

    if Version.compare(latest_version, current_version) == :gt do
      state
      |> set_status({:update_ready, latest_version})
    else
      state
      |> set_status(:no_update_available)
    end
  end

  defp get_latest_downloaded_version() do
    version = get_current_version()

    File.ls!(get_firmware_directory())
    |> Enum.map(fn file ->
      file
      |> String.replace(".fw", "")
      |> Version.parse!()
    end)
    |> Enum.max(Version, fn -> version end)
  end

  defp get_firmware_size(req) do
    case Req.head(req) do
      {:ok, resp} ->
        [size_binary] = Map.get(resp.headers, "content-length", ["0"])
        {size, _} = Integer.parse(size_binary)
        {:ok, size}

      {:error, error} ->
        {:error, error}
    end
  end

  defp check_for_updates(requirement) do
    case @version_provider.get_latest_matching_version(requirement) do
      {:ok, version} ->
        current_version = get_current_version()

        if(Version.compare(version, current_version) == :gt) do
          {:update_available, version}
        else
          :no_update_available
        end

      other ->
        other
    end
  end

  defp get_firmware_file_path(%Version{} = version) do
    version_string = Version.to_string(version)

    Path.join([get_firmware_directory(), "#{version_string}.fw"])
  end

  defp get_firmware_directory() do
    data_directory = Application.get_env(:nerves_update_manager, :data_directory)
    system = Nerves.Runtime.KV.get_active("nerves_fw_platform")

    dir =
      Path.join([data_directory, "NervesUpdateManager", system])

    File.mkdir_p!(dir)

    dir
  end

  defp set_status(state, status) do
    current_status = Map.get(state, :status)

    if current_status != status do
      Logger.debug("[NervesUpdateManager] Setting status to: #{inspect(status)}")

      Registry.dispatch(@registry, @channel, fn entries ->
        for {pid, _} <- entries, do: send(pid, {NervesUpdateManager, status})
      end)

      Map.put(state, :status, status)
    else
      state
    end
  end

  defp get_current_version(),
    do:
      Nerves.Runtime.KV.get_active("nerves_fw_version")
      |> Version.parse!()
end
