# Start the application first
Application.ensure_all_started(:browserforge)
Application.ensure_all_started(:finch)

# Ensure test directories exist
BrowserForge.Test.Setup.ensure_test_dirs()

# Download test data
Mix.Task.run("browserforge.download_test_data")

# Run tests
ExUnit.start()
