defmodule Core.Researcher.Scraper do
  @moduledoc """
  Coordinates webpage scraping and content processing.

  This module manages:
  * Multi-service webpage scraping (Jina, Firecrawl, PureMD)
  * Content validation and cleaning
  * Caching and retrieval of scraped content
  * Parallel processing of webpage content
  * Error handling and timeout management
  * OpenTelemetry tracing and logging

  It implements a fallback strategy across multiple scraping
  services and coordinates the entire scraping pipeline,
  from fetching to processing and storage. The module
  includes robust error handling and supports both
  supervised and unsupervised content processing.
  """

  require Logger
  require OpenTelemetry.Tracer

  alias Core.Utils.Tracing
  alias Core.Utils.TaskAwaiter
  alias Core.Utils.UrlFormatter
  alias Core.Researcher.Webpages
  alias Core.Utils.DomainExtractor
  alias Core.Researcher.Scraper.Jina
  alias Core.Utils.PrimaryDomainFinder
  alias Core.Researcher.Scraper.Filter
  alias Core.Researcher.Scraper.Puremd
  alias Core.Researcher.Scraper.Firecrawl
  alias Core.Researcher.Webpages.Classifier
  alias Core.Researcher.Scraper.ContentProcessor

  # 60 seconds
  @scraper_timeout 60 * 1000

  @err_timeout {:error, :timeout}
  @err_no_content {:error, :no_content}
  @err_invalid_url {:error, :invalid_url}
  @err_unprocessable {:error, :unprocessable}
  @err_url_not_provided {:error, :url_not_provided}
  @err_not_primary_domain {:error, :not_primary_domain}

  @type scrape_result :: %{
          content: String.t(),
          summary: String.t() | nil,
          links: [String.t()] | nil
        }

  def scrape_webpage(url) when is_binary(url) and byte_size(url) > 0 do
    OpenTelemetry.Tracer.with_span "scraper.scrape_webpage" do
      OpenTelemetry.Tracer.set_attributes([
        {"url", url}
      ])

      Logger.metadata(module: __MODULE__, function: :scrape_webpage)

      case validate_url(url) do
        {:error, :should_not_scrape} ->
          Tracing.warning(:should_not_scrape, "Non-scrapeable URL", url: url)
          {:error, :should_not_scrape}

        @err_not_primary_domain ->
          Tracing.warning(:not_primary_domain, "Skipping scrape", url: url)
          @err_not_primary_domain

        @err_no_content ->
          Tracing.warning(
            :no_content,
            "No valid content / content type available by url: #{url}",
            url: url
          )

          @err_no_content

        @err_timeout ->
          Tracing.warning(:timeout, "URL validation timed out", url: url)
          @err_timeout

        {:error, reason} ->
          case reason do
            %Mint.TransportError{reason: :nxdomain} ->
              Tracing.warning(:nxdomain, "Domain does not exist", url: url)
              {:error, :domain_not_found}

            %Mint.TransportError{reason: :timeout} ->
              Tracing.warning(:timeout, "Domain connection timed out", url: url)
              {:error, :connection_timeout}

            %Mint.TransportError{reason: :closed} ->
              Tracing.warning(:connection_closed, "Connection closed by server",
                url: url
              )

              {:error, :connection_closed}

            %Mint.TransportError{} = transport_error ->
              Tracing.warning(
                transport_error.reason,
                "Network error while validating URL",
                url: url
              )

              {:error, :network_error}

            _ ->
              Tracing.error(reason, "Invalid URL for scraping", url: url)
              {:error, reason}
          end

        url ->
          Logger.info("Starting to scrape #{url}", url: url)

          case Core.Researcher.Webpages.get_by_url(url) do
            {:ok, existing_record} -> use_cached_content(existing_record)
            {:error, :not_found} -> fetch_and_process_webpage(url)
          end
      end
    end
  end

  def scrape_webpage(""), do: @err_url_not_provided
  def scrape_webpage(nil), do: @err_url_not_provided
  def scrape_webpage(_), do: @err_invalid_url

  defp fetch_and_process_webpage(url) do
    OpenTelemetry.Tracer.with_span "scraper.fetch_and_process_webpage" do
      OpenTelemetry.Tracer.set_attributes([
        {"url", url}
      ])

      url
      |> fetch_webpage()
      |> process_content(url)
      |> classify_content(url)
    end
  end

  def validate_url(url) do
    OpenTelemetry.Tracer.with_span "scraper.validate_url" do
      OpenTelemetry.Tracer.set_attributes([
        {"url", url}
      ])

      with {:ok, true} <- should_scrape(url),
           {:ok, host} <- DomainExtractor.extract_base_domain(url),
           {:ok, true} <- validate_is_primary_domain(host),
           {:ok, base_url} <- UrlFormatter.get_base_url(url),
           {:ok, clean_url} <- UrlFormatter.to_https(base_url),
           {:ok, content_type} <- fetch_content_type(clean_url),
           {:ok, true} <- webpage_content_type_allow_scrape(content_type) do
        OpenTelemetry.Tracer.set_attributes([
          {"result", "valid"}
        ])

        clean_url
      else
        {:error, :webpage_content_type_not_text_html} ->
          @err_no_content

        {:error, :no_content_type} ->
          @err_no_content

        {:error, :timeout} ->
          OpenTelemetry.Tracer.set_attributes([
            {"result", "timeout"}
          ])

          Logger.info("#{url} validation timed out")
          {:error, :timeout}

        {:error, reason} ->
          OpenTelemetry.Tracer.set_attributes([
            {"result", reason}
          ])

          Logger.info("#{url} is invalid, stopping scraper")
          {:error, reason}
      end
    end
  end

  @spec should_scrape(String.t()) :: {:ok, true} | {:error, :should_not_scrape}
  defp should_scrape(url) do
    case Filter.should_scrape?(url) do
      {:ok, true} -> {:ok, true}
      {:ok, false} -> {:error, :should_not_scrape}
    end
  end

  defp validate_is_primary_domain(url) do
    case PrimaryDomainFinder.primary_domain?(url) do
      true -> {:ok, true}
      false -> @err_not_primary_domain
    end
  end

  defp process_content({:ok, content}, url) do
    OpenTelemetry.Tracer.with_span "scraper.process_content" do
      OpenTelemetry.Tracer.set_attributes([
        {"param.url", url}
      ])

      Logger.metadata(module: __MODULE__, function: :process_content)

      case ContentProcessor.process_scraped_content(url, content) do
        {:ok, content} ->
          {:ok, content}

        {:error, reason} ->
          Tracing.error(reason, "Failed processing scraped content", url: url)

          {:error, reason}
      end
    end
  end

  defp process_content({:error, reason}, _url), do: {:error, reason}

  defp fetch_webpage(url) do
    OpenTelemetry.Tracer.with_span "scraper.fetch_webpage" do
      OpenTelemetry.Tracer.set_attributes([
        {"url", url}
      ])

      with {:error, _jina_reason} <- try_jina(url),
           {:error, _puremd_reason} <- try_puremd(url),
           {:error, firecrawl_reason} <- try_firecrawl(url) do
        handle_fetch_error(firecrawl_reason, url)
      else
        {:ok, content} -> {:ok, content}
      end
    end
  end

  defp classify_content({:ok, content}, url) do
    OpenTelemetry.Tracer.with_span "scraper.classify_content" do
      task = Classifier.classify_content_supervised(url, content)

      case TaskAwaiter.await(task, @scraper_timeout) do
        {:ok, classification} ->
          Webpages.update_classification(url, classification)

          {:ok,
           %{
             content: content
           }}

        {:error, reason} ->
          Tracing.error(reason)
          {:error, reason}
      end
    end
  end

  defp classify_content({:error, reason}, _url), do: {:error, reason}

  defp handle_fetch_error({:http_error, message}, url) do
    Logger.error("HTTP error while attempting to scrape #{url}: #{message}",
      url: url,
      reason: :http_error,
      message: message
    )

    err = "http error => message: #{message}"
    Tracing.error(err)
    {:error, err}
  end

  defp handle_fetch_error(reason, url) do
    Tracing.error(reason, "Failed to scrape #{url}", url: url)
    {:error, reason}
  end

  defp try_jina(url) do
    OpenTelemetry.Tracer.with_span "scraper.try_jina" do
      OpenTelemetry.Tracer.set_attributes([
        {"url", url}
      ])

      Logger.metadata(module: __MODULE__, function: :try_jina)

      Logger.info("Starting to scrape #{url} with Jina",
        url: url
      )

      ctx = OpenTelemetry.Ctx.get_current()

      task =
        Task.Supervisor.async(Core.TaskSupervisor, fn ->
          OpenTelemetry.Ctx.attach(ctx)
          Jina.fetch_page(url)
        end)

      TaskAwaiter.await(task, @scraper_timeout)
    end
  end

  defp try_firecrawl(url) do
    OpenTelemetry.Tracer.with_span "scraper.try_firecrawl" do
      OpenTelemetry.Tracer.set_attributes([
        {"url", url}
      ])

      Logger.metadata(module: __MODULE__, function: :try_firecrawl)

      Logger.info("Starting to scrape #{url} with Firecrawl",
        url: url
      )

      ctx = OpenTelemetry.Ctx.get_current()

      task =
        Task.Supervisor.async(Core.TaskSupervisor, fn ->
          OpenTelemetry.Ctx.attach(ctx)
          Firecrawl.fetch_page(url)
        end)

      TaskAwaiter.await(task, @scraper_timeout)
    end
  end

  defp try_puremd(url) do
    OpenTelemetry.Tracer.with_span "scraper.try_puremd" do
      OpenTelemetry.Tracer.set_attributes([
        {"url", url}
      ])

      Logger.metadata(module: __MODULE__, function: :try_puremd)

      Logger.info("Starting to scrape #{url} with PureMD",
        url: url
      )

      ctx = OpenTelemetry.Ctx.get_current()

      task =
        Task.Supervisor.async(Core.TaskSupervisor, fn ->
          OpenTelemetry.Ctx.attach(ctx)
          Puremd.fetch_page(url)
        end)

      TaskAwaiter.await(task, @scraper_timeout)
    end
  end

  defp use_cached_content(record) do
    {:ok,
     %{
       content: record.content,
       summary: record.summary,
       links: record.links || []
     }}
  end

  @unprocessable_indicators [
    "403 Forbidden",
    "403:",
    "Forbidden",
    "Robot Challenge",
    "error 404",
    "Attention Required! | Cloudflare",
    "Why have I been blocked?",
    "Privacy error",
    "SSL error"
  ]

  @no_content_indicators [
    "no content"
  ]

  def validate_content(""), do: @err_no_content

  def validate_content(content) when is_binary(content) do
    OpenTelemetry.Tracer.with_span "scraper.validate_content" do
      cond do
        contains_any?(content, @no_content_indicators) ->
          @err_no_content

        contains_any?(content, @unprocessable_indicators) ->
          indicator =
            Enum.find(@unprocessable_indicators, &String.contains?(content, &1))

          indicator_pos =
            String.length(content) -
              String.length(
                String.replace(content, indicator, "", global: false)
              )

          start_pos = max(0, indicator_pos - 50)

          end_pos =
            min(
              String.length(content),
              indicator_pos + String.length(indicator) + 50
            )

          context = String.slice(content, start_pos, end_pos - start_pos)
          context = if start_pos > 0, do: "..." <> context, else: context

          context =
            if end_pos < String.length(content),
              do: context <> "...",
              else: context

          OpenTelemetry.Tracer.set_attributes([
            {"content.context", context},
            {"content.indicator", indicator}
          ])

          @err_unprocessable

        true ->
          {:ok, content}
      end
    end
  end

  def fetch_content_type(
        url,
        depth \\ 0,
        visited \\ MapSet.new(),
        last_known_content_type \\ nil
      ) do
    OpenTelemetry.Tracer.with_span "scraper.fetch_content_type" do
      OpenTelemetry.Tracer.set_attributes([
        {"param.url", url},
        {"param.depth", depth},
        {"param.visited", visited},
        {"param.last_known_content_type", last_known_content_type}
      ])

      cond do
        depth > 10 ->
          {:error, :too_many_redirects}

        not valid_url?(url) ->
          Logger.warning(
            "Invalid URL format in fetch_content_type: #{inspect(url)}"
          )

          {:error, :invalid_url}

        true ->
          make_request(url, depth, visited, last_known_content_type)
      end
    end
  end

  # Add this helper function to validate URL format
  defp valid_url?(url) when is_binary(url) do
    case URI.parse(url) do
      %URI{scheme: scheme, host: host}
      when scheme in ["http", "https"] and not is_nil(host) ->
        true

      _ ->
        false
    end
  end

  defp valid_url?(_), do: false

  # Extract the request logic to a separate function
  defp make_request(url, depth, visited, last_known_content_type) do
    case execute_finch_request(url, :default) do
      {:ok, %Finch.Response{headers: headers, status: status}} ->
        OpenTelemetry.Tracer.set_attributes([{"result.status", status}])

        handle_fetch_content_type_successful_response(
          url,
          headers,
          status,
          depth,
          visited,
          last_known_content_type
        )

      {:error, %Mint.TransportError{reason: :timeout}} ->
        {:error, :timeout}

      {:error, %Mint.TransportError{reason: {:tls_alert, _}}} ->
        Logger.warning(
          "TLS verification failed for #{url}, trying with relaxed verification"
        )

        make_request_with_relaxed_tls(
          url,
          depth,
          visited,
          last_known_content_type
        )

      {:error, reason} ->
        Logger.warning(
          "Finch request failed for URL #{url}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  rescue
    e in ArgumentError ->
      Logger.error(
        "ArgumentError in fetch_content_type for URL #{url}: #{Exception.message(e)}"
      )

      {:error, :invalid_url}
  end

  # Fallback function for TLS verification failures
  defp make_request_with_relaxed_tls(
         url,
         depth,
         visited,
         last_known_content_type
       ) do
    case execute_finch_request(url, :relaxed_tls) do
      {:ok, %Finch.Response{headers: headers, status: status}} ->
        OpenTelemetry.Tracer.set_attributes([{"result.status", status}])

        handle_fetch_content_type_successful_response(
          url,
          headers,
          status,
          depth,
          visited,
          last_known_content_type
        )

      {:error, reason} ->
        Logger.warning(
          "Relaxed TLS request also failed for URL #{url}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  rescue
    e in ArgumentError ->
      Logger.error(
        "ArgumentError in relaxed TLS request for URL #{url}: #{Exception.message(e)}"
      )

      {:error, :invalid_url}
  end

  # Shared helper function for executing Finch requests
  defp execute_finch_request(url, pool) do
    {finch_name, request_opts} =
      case pool do
        :default ->
          {Core.Finch, [receive_timeout: 30_000]}

        :relaxed_tls ->
          {Core.FinchRelaxedTLS,
           [
             receive_timeout: 30_000,
             pool_timeout: 30_000,
             request_timeout: 30_000
           ]}
      end

    Finch.build(:get, url)
    |> Finch.request(finch_name, request_opts)
  end

  defp handle_fetch_content_type_successful_response(
         url,
         headers,
         status,
         depth,
         visited,
         last_known_content_type
       ) do
    content_type = extract_content_type(headers)
    disposition = extract_disposition(headers)
    location = extract_location(headers)

    cond do
      status in 300..399 and location ->
        handle_redirect(
          url,
          location,
          content_type,
          depth,
          visited,
          last_known_content_type
        )

      is_nil(content_type) ->
        {:error, :no_content_type}

      html_download_redirect?(content_type, disposition) ->
        {:error, :html_download_redirect}

      true ->
        {:ok, content_type}
    end
  end

  defp extract_content_type(headers) do
    Enum.find_value(headers, fn
      {"content-type", ct} -> ct
      {"Content-Type", ct} -> ct
      _ -> nil
    end)
  end

  defp extract_disposition(headers) do
    Enum.find_value(headers, fn
      {"content-disposition", disp} -> disp
      {"Content-Disposition", disp} -> disp
      _ -> nil
    end)
  end

  defp extract_location(headers) do
    Enum.find_value(headers, fn
      {"location", loc} -> loc
      {"Location", loc} -> loc
      _ -> nil
    end)
  end

  defp handle_redirect(
         url,
         location,
         content_type,
         depth,
         visited,
         last_known_content_type
       ) do
    next_url = build_next_url(url, location)

    if MapSet.member?(visited, next_url) do
      handle_visited_redirect(content_type, last_known_content_type)
    else
      handle_new_redirect(
        next_url,
        url,
        content_type,
        depth,
        visited,
        last_known_content_type
      )
    end
  end

  defp build_next_url(url, location) do
    cond do
      String.match?(location, ~r/^https?:\/\//) ->
        location

      String.starts_with?(location, "/") ->
        case URI.parse(url) do
          %URI{scheme: scheme, host: host}
          when not is_nil(scheme) and not is_nil(host) ->
            URI.merge(URI.parse(url), location) |> URI.to_string()

          _ ->
            Logger.warning(
              "Cannot build valid URL from base: #{url}, location: #{location}"
            )

            location
        end

      true ->
        case URI.parse(url) do
          %URI{scheme: scheme, host: host, path: path}
          when not is_nil(scheme) and not is_nil(host) ->
            base_path = if path, do: Path.dirname(path), else: "/"
            new_path = Path.join(base_path, location)
            %URI{scheme: scheme, host: host, path: new_path} |> URI.to_string()

          _ ->
            Logger.warning(
              "Cannot build valid URL from base: #{url}, location: #{location}"
            )

            location
        end
    end
  end

  defp handle_visited_redirect(content_type, last_known_content_type) do
    cond do
      not is_nil(content_type) and content_type != "" ->
        {:ok, content_type}

      not is_nil(last_known_content_type) and last_known_content_type != "" ->
        {:ok, last_known_content_type}

      true ->
        {:error, :no_content_type}
    end
  end

  defp handle_new_redirect(
         next_url,
         url,
         content_type,
         depth,
         visited,
         last_known_content_type
       ) do
    updated_content_type =
      if content_type == "" or is_nil(content_type),
        do: last_known_content_type,
        else: content_type

    if valid_url?(next_url) do
      fetch_content_type(
        next_url,
        depth + 1,
        MapSet.put(visited, url),
        updated_content_type
      )
    else
      Logger.warning("Invalid redirect URL: #{next_url}")
      {:error, :invalid_redirect_url}
    end
  end

  defp html_download_redirect?(content_type, disposition) do
    String.contains?(content_type, "text/html") and
      not is_nil(disposition) and
      Regex.match?(~r/attachment/i, disposition)
  end

  defp webpage_content_type_allow_scrape(content_type) do
    if String.starts_with?(content_type, "text/html") do
      {:ok, true}
    else
      {:error, :webpage_content_type_not_text_html}
    end
  end

  defp contains_any?(content, indicators) do
    Enum.any?(indicators, &String.contains?(content, &1))
  end
end
