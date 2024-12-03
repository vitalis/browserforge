ExUnit.start()
ExUnit.configure(exclude: [:integration])

# Set up Mox
Application.ensure_all_started(:mox)

# Define our mock
Mox.defmock(BrowserForge.MockDownload, for: BrowserForge.DownloadBehaviour)

Code.require_file("support/fixtures.ex", __DIR__)
