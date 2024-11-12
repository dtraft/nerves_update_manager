defmodule NervesUpdateManager.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        # Starts a registry for status subscriptions
        {Registry, [keys: :duplicate, name: NervesUpdateManagerSubscriptions, partitions: 1]},
        NervesUpdateManager
      ] ++ scheduler()

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: NervesUpdateManager.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp scheduler() do
    case Application.get_env(:nerves_update_manager, :interval) do
      interval when is_integer(interval) ->
        download? = Application.get_env(:nerves_update_manager, :download?)
        [{NervesUpdateManager.Scheduler, [interval: interval, download?: download?]}]

      _ ->
        []
    end
  end
end
