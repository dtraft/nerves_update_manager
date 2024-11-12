import Config

config :nerves_update_manager,
  firmware_provider: ReflectOSUpdateProvider,
  version_provider: ReflectOSUpdateProvider,
  data_directory: "./data",
  requirement: "> 0.1.0 and < 2.0.0",
  interval: 3_600_000,
  download?: true
