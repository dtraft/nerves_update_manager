defmodule NervesUpdateManager.Scheduler do
  @moduledoc false

  use GenServer

  def start_link(opts) when is_list(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    state = %{
      interval: Keyword.get(opts, :interval, 3_600_00),
      download?: Keyword.get(opts, :download?, false)
    }

    # Subscribe to status updates
    NervesUpdateManager.subscribe()

    NervesUpdateManager.check_for_updates()
    Process.send_after(self(), :check_for_updates, state[:interval])

    {:ok, state}
  end

  @impl true
  def handle_info(
        {NervesUpdateManager, {:update_available, _version}},
        %{download?: true} = state
      ) do
    NervesUpdateManager.download_update()
    {:noreply, state}
  end

  # Ignore any other status messages
  def handle_info({NervesUpdateManager, _}, state) do
    {:noreply, state}
  end

  def handle_info(:check_for_updates, state) do
    NervesUpdateManager.check_for_updates()
    Process.send_after(self(), :check_for_updates, state[:interval])
    {:noreply, state}
  end
end
