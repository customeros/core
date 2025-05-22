defmodule Finch.Behaviour do
  @callback request(Finch.Request.t(), atom(), keyword()) :: {:ok, Finch.Response.t()} | {:error, term()}
end

# Define mocks
Mox.defmock(Core.External.IPData.Service.Mock, for: Core.External.IPData.Behaviour)
Mox.defmock(Core.WebTracker.IPIntelligence.Mock, for: Core.WebTracker.IPIntelligenceBehaviour)
Mox.defmock(FinchMock, for: Finch.Behaviour)
Mox.defmock(Core.External.Jina.Service.Mock, for: Core.External.Jina.Behaviour)
Mox.defmock(Core.External.Puremd.Service.Mock, for: Core.External.Puremd.Behaviour)
Mox.defmock(Core.Scraper.Repository.Mock, for: Core.Scraper.Repository.Behaviour)

defmodule Core.Mocks do
  @moduledoc """
  Defines all mocks used in tests.
  """

  # Define mocks for external services
  Mox.defmock(Core.External.Anthropic.Service.Mock, for: Core.External.Anthropic.Behaviour)
  Mox.defmock(Core.External.Jina.Service.Mock, for: Core.External.Jina.Behaviour)
  Mox.defmock(Core.External.Puremd.Service.Mock, for: Core.External.Puremd.Behaviour)

  # Define mocks for internal services
  Mox.defmock(Core.Scraper.Repository.Mock, for: Core.Scraper.Repository.Behaviour)
  Mox.defmock(Core.Ai.Webpage.Classify.Mock, for: Core.Ai.Webpage.Classify.Behaviour)
  Mox.defmock(Core.Ai.Webpage.ProfileIntent.Mock, for: Core.Ai.Webpage.ProfileIntent.Behaviour)
end
