defmodule Core.Scraper.CrawlerTest do
  use Core.DataCase
  import Mox
  alias Core.Scraper.Crawler
  alias Core.ScraperFixtures

  # Make sure mocks are verified when the test exits
  setup :verify_on_exit!

  setup do
    # Set up test configuration for Jina and PureMD services
    Application.put_env(:core, :jina, %{
      jina_api_key: "test_key",
      jina_api_path: "https://api.jina.ai/v1/"
    })

    Application.put_env(:core, :puremd, %{
      puremd_api_key: "test_key",
      puremd_api_path: "https://api.puremd.ai/v1/"
    })

    # Configure the mocks to be used
    Application.put_env(:core, :jina_service, Core.External.Jina.Service.Mock)
    Application.put_env(:core, :puremd_service, Core.External.Puremd.Service.Mock)
    Application.put_env(:core, :scraper_repository, Core.Scraper.Repository.Mock)
    Application.put_env(:core, :classify_service, Core.Ai.Webpage.Classify.Mock)
    Application.put_env(:core, :profile_intent_service, Core.Ai.Webpage.ProfileIntent.Mock)

    # Mock the classification and intent services
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
         problem_recognition: 0.5,
         solution_research: 0.5,
         evaluation: 0.5,
         purchase_readiness: 0.5
       }}
    end)

    :ok
  end

  describe "start/2" do
    test "successfully crawls a valid domain" do
      domain = "example.com"
      content = Core.ScraperFixtures.valid_html()

      Core.External.Jina.Service.Mock
      |> expect(:fetch_page, fn url ->
        assert url == "https://example.com"
        {:ok, content}
      end)

      Core.External.Puremd.Service.Mock
      |> stub(:fetch_page, fn url ->
        assert url == "https://example.com"
        {:error, "Not needed"}
      end)

      # Mock the repository to ensure no cached content exists
      Core.Scraper.Repository.Mock
      |> expect(:get_by_url, fn url ->
        assert url == "https://example.com"
        nil
      end)
      |> expect(:save_scraped_content, fn url, content, links, _classification, _intent ->
        assert url == "https://example.com"
        {:ok, %{url: url, content: content, links: links}}
      end)

      assert {:ok, results} = Crawler.start(domain)
      assert map_size(results) > 0
    end

    test "handles invalid domain" do
      assert {:error, reason} = Crawler.start("invalid-domain")
      assert reason =~ "Invalid domain"
    end

    test "respects max_depth" do
      domain = "example.com"
      content = Core.ScraperFixtures.valid_html()

      Core.External.Jina.Service.Mock
      |> expect(:fetch_page, fn url ->
        assert url == "https://example.com"
        {:ok, content}
      end)

      Core.External.Puremd.Service.Mock
      |> stub(:fetch_page, fn url ->
        assert url == "https://example.com"
        {:error, "Not needed"}
      end)

      # Mock the repository to ensure no cached content exists
      Core.Scraper.Repository.Mock
      |> expect(:get_by_url, fn url ->
        assert url == "https://example.com"
        nil
      end)
      |> expect(:save_scraped_content, fn url, content, links, _classification, _intent ->
        assert url == "https://example.com"
        {:ok, %{url: url, content: content, links: links}}
      end)

      assert {:ok, results} = Crawler.start(domain, max_depth: 1)
      assert map_size(results) > 0
    end

    test "respects max_pages" do
      domain = "example.com"
      content = Core.ScraperFixtures.valid_html()

      Core.External.Jina.Service.Mock
      |> expect(:fetch_page, fn url ->
        assert url == "https://example.com"
        {:ok, content}
      end)

      Core.External.Puremd.Service.Mock
      |> stub(:fetch_page, fn url ->
        assert url == "https://example.com"
        {:error, "Not needed"}
      end)

      # Mock the repository to ensure no cached content exists
      Core.Scraper.Repository.Mock
      |> expect(:get_by_url, fn url ->
        assert url == "https://example.com"
        nil
      end)
      |> expect(:save_scraped_content, fn url, content, links, _classification, _intent ->
        assert url == "https://example.com"
        {:ok, %{url: url, content: content, links: links}}
      end)

      assert {:ok, results} = Crawler.start(domain, max_pages: 1)
      assert map_size(results) == 1
    end

    test "handles network errors" do
      domain = "example.com"

      # Mock the repository to ensure no cached content exists
      Core.Scraper.Repository.Mock
      |> expect(:get_by_url, fn url ->
        assert url == "https://example.com"
        nil
      end)

      # Jina service should be called first
      Core.External.Jina.Service.Mock
      |> expect(:fetch_page, fn url ->
        assert url == "https://example.com"
        {:error, %Mint.TransportError{reason: :closed}}
      end)

      # PureMD service should be called after Jina fails
      Core.External.Puremd.Service.Mock
      |> expect(:fetch_page, fn url ->
        assert url == "https://example.com"
        {:error, %Mint.TransportError{reason: :closed}}
      end)

      assert {:ok, results} = Crawler.start(domain)
      assert map_size(results) == 0
    end

    test "handles timeouts" do
      domain = "example.com"

      Core.External.Jina.Service.Mock
      |> expect(:fetch_page, fn url ->
        assert url == "https://example.com"
        {:error, %Mint.TransportError{reason: :timeout}}
      end)

      Core.External.Puremd.Service.Mock
      |> expect(:fetch_page, fn url ->
        assert url == "https://example.com"
        {:error, %Mint.TransportError{reason: :timeout}}
      end)

      # Mock the repository to ensure no cached content exists
      Core.Scraper.Repository.Mock
      |> expect(:get_by_url, fn url ->
        assert url == "https://example.com"
        nil
      end)

      assert {:ok, results} = Crawler.start(domain)
      assert map_size(results) == 0
    end

    test "handles rate limiting" do
      domain = "example.com"

      Core.External.Jina.Service.Mock
      |> expect(:fetch_page, fn url ->
        assert url == "https://example.com"
        {:error, "Rate limit exceeded"}
      end)

      Core.External.Puremd.Service.Mock
      |> expect(:fetch_page, fn url ->
        assert url == "https://example.com"
        {:error, "Rate limit exceeded"}
      end)

      # Mock the repository to ensure no cached content exists
      Core.Scraper.Repository.Mock
      |> expect(:get_by_url, fn url ->
        assert url == "https://example.com"
        nil
      end)

      assert {:ok, results} = Crawler.start(domain)
      assert map_size(results) == 0
    end
  end
end
