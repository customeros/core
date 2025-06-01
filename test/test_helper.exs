ExUnit.start()

# Exclude integration tests by default
ExUnit.configure(exclude: [:integration, :external])

# Start required applications for testing
Application.ensure_all_started(:finch)
Application.ensure_all_started(:jason)
