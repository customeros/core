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
    test "missing API key returns configuration error" do
      assert {:error, "PureMD API key not set"} =
               Puremd.fetch_page("https://example.com")
    end
  end
end
