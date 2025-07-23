import Config

# Only in tests, remove the complexity from the password hashing algorithm
config :bcrypt_elixir, :log_rounds, 1

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :emberchat, Emberchat.Repo,
  database: Path.expand("../emberchat_test.db", __DIR__),
  pool_size: 5,
  pool: Ecto.Adapters.SQL.Sandbox,
  # Load sqlite-vec extension - using path without .so extension as expected by SqliteVec.path()
  load_extensions: [Path.expand("../deps/sqlite_vec/priv/0.1.5/vec0", __DIR__)]

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :emberchat, EmberchatWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "gjkgvsNheGe89B/8Wc9spbaArYSfTqzHKoEEzpxJsIlgVWlHKiMsVx20GUUWny3q",
  server: false

# In test we don't send emails
config :emberchat, Emberchat.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
