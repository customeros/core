defmodule Core.Researcher.ScraperTest do
  alias Core.Researcher.Scraper
  use ExUnit.Case
  use ExUnitProperties
  import StreamData

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Core.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Core.Repo, {:shared, self()})
    :ok

    original_firecrawl = Application.get_env(:core, :firecrawl)
    original_jina = Application.get_env(:core, :jina)
    original_puremd = Application.get_env(:core, :puremd)

    Application.put_env(:core, :firecrawl,
      firecrawl_api_key: nil,
      firecrawl_api_path: "https://test.example.com"
    )

    Application.put_env(:core, :jina,
      firecrawl_api_key: nil,
      firecrawl_api_path: "https://test.example.com"
    )

    Application.put_env(:core, :puremd,
      firecrawl_api_key: nil,
      firecrawl_api_path: "https://test.example.com"
    )

    # Restore after test
    on_exit(fn ->
      if original_firecrawl do
        Application.put_env(:core, :firecrawl, original_firecrawl)
      else
        Application.delete_env(:core, :firecrawl)
      end

      if original_puremd do
        Application.put_env(:core, :puremd, original_puremd)
      else
        Application.delete_env(:core, :puremd)
      end

      if original_jina do
        Application.put_env(:core, :jina, original_jina)
      else
        Application.delete_env(:core, :jina)
      end
    end)

    :ok
  end

  describe "scrape_webpage/1 - return type guarantees" do
    property "always returns tagged tuple with specific error shapes" do
      check all(
              url <-
                one_of([
                  string(:alphanumeric),
                  string(:utf8),
                  constant(""),
                  constant(nil),
                  integer()
                ])
            ) do
        result = Scraper.scrape_webpage(url)

        case result do
          {:ok, content} when is_binary(content) ->
            assert String.length(content) > 0

          {:error, %{type: error_type}} when is_atom(error_type) ->
            :ok

          {:error, _} ->
            :ok

          other ->
            flunk("Unexpected return shape: #{inspect(other)}")
        end
      end
    end

    test "with empty string returns url_not_provided error" do
      assert {:error, :url_not_provided} = Scraper.scrape_webpage("")
    end

    test "with nil returns url_not_provided error" do
      assert {:error, :url_not_provided} =
               Scraper.scrape_webpage(nil)
    end

    test "with non-string returns invalid_url error" do
      assert {:error, :invalid_url} = Scraper.scrape_webpage(0456)
    end
  end
end
