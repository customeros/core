ExUnit.start()

# Add test directory to code path
Code.prepend_path("test")

# Set up mocks
Mox.defmock(FinchMock, for: Finch.Behaviour)
Application.put_env(:core, :finch, FinchMock)

# Define mocks for services
Mox.defmock(Core.External.Jina.Service.Mock,
  for: Core.External.Jina.Service.Behaviour
)

Mox.defmock(Core.External.Puremd.Service.Mock,
  for: Core.External.Puremd.Service.Behaviour
)

Mox.defmock(Core.Scraper.Repository.Mock,
  for: Core.Scraper.Repository.Behaviour
)

Mox.defmock(Core.Ai.Webpage.Classify.Mock,
  for: Core.Ai.Webpage.Classify.Behaviour
)

Mox.defmock(Core.Ai.Webpage.ProfileIntent.Mock,
  for: Core.Ai.Webpage.ProfileIntent.Behaviour
)

Mox.defmock(Core.WebTracker.IPIntelligence.Mock,
  for: Core.WebTracker.IPIntelligenceBehaviour
)

# Ensure DataCase is loaded
Code.require_file("test/support/data_case.ex")
