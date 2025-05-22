defmodule Core.Scraper.ScrapeTest do
  use Core.DataCase
  import Mox

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  setup do
    # Set up test configuration for services
    Application.put_env(:core, :jina, %{
      jina_api_key: "test_key",
      jina_api_path: "https://api.jina.ai/v1/"
    })

    Application.put_env(:core, :puremd, %{
      puremd_api_key: "test_key",
      puremd_api_path: "https://api.puremd.com/v1/"
    })

    # Configure the mocks to be used
    Application.put_env(:core, :jina_service, Core.External.Jina.Service.Mock)
    Application.put_env(:core, :puremd_service, Core.External.Puremd.Service.Mock)
    Application.put_env(:core, :scraper_repository, Core.Scraper.Repository.Mock)
    Application.put_env(:core, :classify_service, Core.Ai.Webpage.Classify.Mock)
    Application.put_env(:core, :profile_intent_service, Core.Ai.Webpage.ProfileIntent.Mock)

    :ok
  end

  alias Core.Scraper.Scrape
  alias Core.ScraperFixtures

  describe "scrape_webpage/1" do
    test "successfully scrapes a valid URL" do
      url = "https://example.com"
      content = Core.ScraperFixtures.valid_html()

      Core.Scraper.Repository.Mock
      |> expect(:get_by_url, fn ^url -> nil end)

      Core.Ai.Webpage.Classify.Mock
      |> expect(:classify_webpage_content, fn _domain, _content ->
        {:ok,
         %Core.Ai.Webpage.Classification{
           primary_topic: "test",
           secondary_topics: [],
           solution_focus: [],
           content_type: :landing_page,
           industry_vertical: "test",
           key_pain_points: [],
           value_proposition: "test",
           referenced_customers: []
         }}
      end)

      Core.Ai.Webpage.ProfileIntent.Mock
      |> expect(:profile_webpage_intent, fn _domain, _content ->
        {:ok,
         %Core.Ai.Webpage.Intent{
           problem_recognition: 1,
           solution_research: 1,
           evaluation: 1,
           purchase_readiness: 1
         }}
      end)

      # Mock Jina service to succeed
      Core.External.Jina.Service.Mock
      |> expect(:fetch_page, fn _url ->
        {:ok, content}
      end)

      # PureMD should not be called if Jina succeeds, so use stub
      Core.External.Puremd.Service.Mock
      |> stub(:fetch_page, fn _url ->
        {:error, "Not needed"}
      end)

      # Mock repository to return no cached content
      Core.Scraper.Repository.Mock
      |> expect(:save_scraped_content, fn url, content, links, _classification, _intent ->
        {:ok, %{url: url, content: content, links: links}}
      end)

      assert {:ok, result} = Scrape.scrape_webpage(url)
      assert result.content =~ "Example Domain"
    end

    test "handles network errors" do
      url = "https://example.com"

      Core.Scraper.Repository.Mock
      |> expect(:get_by_url, fn ^url -> nil end)

      # These will not be called if both services fail, so use stub
      Core.Ai.Webpage.Classify.Mock
      |> stub(:classify_webpage_content, fn _domain, _content ->
        {:ok,
         %Core.Ai.Webpage.Classification{
           primary_topic: "test",
           secondary_topics: [],
           solution_focus: [],
           content_type: :landing_page,
           industry_vertical: "test",
           key_pain_points: [],
           value_proposition: "test",
           referenced_customers: []
         }}
      end)

      Core.Ai.Webpage.ProfileIntent.Mock
      |> stub(:profile_webpage_intent, fn _domain, _content ->
        {:ok,
         %Core.Ai.Webpage.Intent{
           problem_recognition: 1,
           solution_research: 1,
           evaluation: 1,
           purchase_readiness: 1
         }}
      end)

      Core.Scraper.Repository.Mock
      |> stub(:save_scraped_content, fn _url, _content, _links, _classification, _intent ->
        {:ok, %{}}
      end)

      Core.External.Jina.Service.Mock
      |> expect(:fetch_page, fn _url ->
        {:error, %Mint.TransportError{reason: :closed}}
      end)

      Core.External.Puremd.Service.Mock
      |> expect(:fetch_page, fn _url ->
        {:error, %Mint.TransportError{reason: :closed}}
      end)

      assert {:error, reason} = Scrape.scrape_webpage(url)
      assert reason =~ "Transport error"
    end

    test "handles timeouts" do
      url = "https://example.com"

      Core.Scraper.Repository.Mock
      |> expect(:get_by_url, fn ^url -> nil end)

      # These will not be called if both services fail, so use stub
      Core.Ai.Webpage.Classify.Mock
      |> stub(:classify_webpage_content, fn _domain, _content ->
        {:ok,
         %Core.Ai.Webpage.Classification{
           primary_topic: "test",
           secondary_topics: [],
           solution_focus: [],
           content_type: :landing_page,
           industry_vertical: "test",
           key_pain_points: [],
           value_proposition: "test",
           referenced_customers: []
         }}
      end)

      Core.Ai.Webpage.ProfileIntent.Mock
      |> stub(:profile_webpage_intent, fn _domain, _content ->
        {:ok,
         %Core.Ai.Webpage.Intent{
           problem_recognition: 1,
           solution_research: 1,
           evaluation: 1,
           purchase_readiness: 1
         }}
      end)

      Core.Scraper.Repository.Mock
      |> stub(:save_scraped_content, fn _url, _content, _links, _classification, _intent ->
        {:ok, %{}}
      end)

      Core.External.Jina.Service.Mock
      |> expect(:fetch_page, fn _url ->
        {:error, %Mint.TransportError{reason: :timeout}}
      end)

      Core.External.Puremd.Service.Mock
      |> expect(:fetch_page, fn _url ->
        {:error, %Mint.TransportError{reason: :timeout}}
      end)

      assert {:error, reason} = Scrape.scrape_webpage(url)
      assert reason =~ "Transport error"
    end

    test "handles rate limiting" do
      url = "https://example.com"

      Core.Scraper.Repository.Mock
      |> expect(:get_by_url, fn ^url -> nil end)

      # These will not be called if both services fail, so use stub
      Core.Ai.Webpage.Classify.Mock
      |> stub(:classify_webpage_content, fn _domain, _content ->
        {:ok,
         %Core.Ai.Webpage.Classification{
           primary_topic: "test",
           secondary_topics: [],
           solution_focus: [],
           content_type: :landing_page,
           industry_vertical: "test",
           key_pain_points: [],
           value_proposition: "test",
           referenced_customers: []
         }}
      end)

      Core.Ai.Webpage.ProfileIntent.Mock
      |> stub(:profile_webpage_intent, fn _domain, _content ->
        {:ok,
         %Core.Ai.Webpage.Intent{
           problem_recognition: 1,
           solution_research: 1,
           evaluation: 1,
           purchase_readiness: 1
         }}
      end)

      Core.Scraper.Repository.Mock
      |> stub(:save_scraped_content, fn _url, _content, _links, _classification, _intent ->
        {:ok, %{}}
      end)

      Core.External.Jina.Service.Mock
      |> expect(:fetch_page, fn _url ->
        {:error, "Rate limit exceeded"}
      end)

      Core.External.Puremd.Service.Mock
      |> expect(:fetch_page, fn _url ->
        {:error, "Rate limit exceeded"}
      end)

      assert {:error, reason} = Scrape.scrape_webpage(url)
      assert reason =~ "Both services failed"
      assert reason =~ "Rate limit exceeded"
    end

    test "handles malformed HTML" do
      url = "https://example.com"
      content = "<html><body><p>Unclosed paragraph"

      Core.Scraper.Repository.Mock
      |> expect(:get_by_url, fn ^url -> nil end)

      Core.Ai.Webpage.Classify.Mock
      |> expect(:classify_webpage_content, fn _domain, _content ->
        {:ok,
         %Core.Ai.Webpage.Classification{
           primary_topic: "test",
           secondary_topics: [],
           solution_focus: [],
           content_type: :landing_page,
           industry_vertical: "test",
           key_pain_points: [],
           value_proposition: "test",
           referenced_customers: []
         }}
      end)

      Core.Ai.Webpage.ProfileIntent.Mock
      |> expect(:profile_webpage_intent, fn _domain, _content ->
        {:ok,
         %Core.Ai.Webpage.Intent{
           problem_recognition: 1,
           solution_research: 1,
           evaluation: 1,
           purchase_readiness: 1
         }}
      end)

      Core.External.Jina.Service.Mock
      |> expect(:fetch_page, fn _url ->
        {:ok, content}
      end)

      Core.Scraper.Repository.Mock
      |> expect(:save_scraped_content, fn url, content, links, _classification, _intent ->
        {:ok, %{url: url, content: content, links: links}}
      end)

      assert {:ok, result} = Scrape.scrape_webpage(url)
      assert result.content =~ "Unclosed paragraph"
    end

    test "scrape_webpage/1 handles rate limiting" do
      url = "https://example.com"
      # Expect the repository to be checked for the URL
      Core.Scraper.Repository.Mock
      |> expect(:get_by_url, fn ^url -> nil end)

      Core.External.Jina.Service.Mock
      |> expect(:fetch_page, fn ^url -> {:error, "Rate limit exceeded"} end)

      Core.External.Puremd.Service.Mock
      |> expect(:fetch_page, fn ^url -> {:error, "Rate limit exceeded"} end)

      assert {:error, reason} = Scrape.scrape_webpage(url)
      assert reason =~ "Both services failed"
      assert reason =~ "Rate limit exceeded"
    end
  end
end
