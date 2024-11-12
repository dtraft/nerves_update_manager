import Config

config :nerves_update_manager,
  firmware_provider: TestProvider,
  version_provider: TestProvider,
  data_directory: "./data",
  requirement: "> 0.1.0 and < 2.0.0",
  interval: nil,
  download?: false
