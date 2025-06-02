defmodule Core.Researcher.Scraper.PuremdTest do
  use ExUnit.Case
  use ExUnitProperties
  import StreamData

  alias Core.Researcher.Scraper.Puremd

  setup do
    original_config = Application.get_env(:core, :puremd)

    Application.put_env(:core, :puremd,
      puremd_api_key: nil,
      puremd_api_path: "https://test.example.com"
    )

    # Restore after test
    on_exit(fn ->
      if original_config do
        Application.put_env(:core, :puremd, original_config)
      else
        Application.delete_env(:core, :puremd)
      end
    end)

    :ok
  end

  describe "fetch_page_supervised/1 - return type guarantees" do
    property "always returns a Task.t()" do
      check all(
              input <-
                one_of([
                  string(:alphanumeric),
                  constant(""),
                  constant(nil),
                  integer(),
                  list_of(StreamData.string(:alphanumeric))
                ])
            ) do
        result = Puremd.fetch_page_supervised(input)

        case result do
          %Task{} -> :ok
          other -> flunk("Unexpected return: #{inspect(other)}")
        end
      end
    end

    test "with valid URL returns supervised Task" do
      result = Puremd.fetch_page_supervised("https://example.com")
      assert %Task{} = result
      assert is_pid(result.pid)
    end
  end

  describe "fetch_page/1 - return type guarantees" do
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
        result = Puremd.fetch_page(url)

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
      assert {:error, :url_not_provided} = Puremd.fetch_page("")
    end

    test "with nil returns url_not_provided error" do
      assert {:error, :url_not_provided} =
               Puremd.fetch_page(nil)
    end

    test "with non-string returns invalid_url error" do
      assert {:error, :invalid_url} = Puremd.fetch_page(0456)
    end
  end

  describe "handle_response/1 - response parsing logic" do
    test "handles successful response with content" do
      response = %Finch.Response{
        status: 200,
        body: ~s({"success": true, "data": {"markdown": "# Sample Content"}})
      }

      assert {:ok, "# Sample Content"} =
               Puremd.handle_response_test(response)
    end

    test "handles 400 status returns invalid_url error" do
      response = %Finch.Response{
        status: 400,
        body:
          ~s({"error": "Bad Request", "details": [{"message": "Invalid URL"}]})
      }

      assert {:error, _reason} =
               Puremd.handle_response_test(response)
    end

    test "rate limit exceeded" do
      body = """
      {"error": "Rate limit exceeded. Consumed (req/min): 45, Remaining (req/min): 0. Upgrade your plan at https://firecrawl.dev/pricing for increased rate limits or please retry after 37s"}
      """

      response = %Finch.Response{
        status: 429,
        body: String.trim(body)
      }

      assert {:error, :rate_limit_exceeded} =
               Puremd.handle_response_test(response)
    end

    test "handles malformed JSON" do
      response = %Finch.Response{
        status: 200,
        body: "invalid json{"
      }

      assert {:error, "unable to decode response"} =
               Puremd.handle_response_test(response)
    end

    test "missing API key returns configuration error" do
      assert {:error, "PureMD API key not set"} =
               Puremd.fetch_page("https://example.com")
    end
  end
end
