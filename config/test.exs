import Config

config :logger, :default_handler,
  level: if(System.get_env("DEBUG") == "1", do: :debug, else: :warning)
