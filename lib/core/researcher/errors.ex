defmodule Core.Researcher.Errors do
  @moduledoc """
  Common error definitions for the researcher package
  """

  @url_errors [
    :url_not_provided,
    :invalid_url
  ]

  @config_errors [
    :jina_api_key_not_set,
    :jina_api_path_not_set
  ]

  @http_errors [
    :http_error
  ]

  @jina_errors [
    :payment_required
  ]

  @scraper_errors [
    :unprocessable,
    :webscraper_timeout,
    :no_content,
    :content_classification_timeout,
    :intent_profiler_timeout,
    :content_summary_timeout,
    :empty_content,
    :invalid_content_type
  ]

  @valid_errors @url_errors ++
                  @config_errors ++
                  @http_errors ++
                  @jina_errors ++ @scraper_errors

  @type url_error ::
          :invalid_url
          | :url_not_provided

  @type config_error ::
          :jina_api_key_not_set
          | :jina_api_path_not_set
          | :puremd_api_key_not_set
          | :puremd_api_path_not_set

  @type http_error :: :http_error

  @type jina_error ::
          :payment_required

  @type scraper_error ::
          :unprocessable
          | :no_content
          | :webscraper_timeout
          | :content_classification_timeout
          | :intent_profiler_timeout
          | :content_summary_timeout
          | :empty_content
          | :invalid_content_type

  @type researcher_error ::
          url_error()
          | config_error()
          | http_error()
          | jina_error()
          | scraper_error()

  @doc """
  Creates a standardized error tuple.
  """
  @spec error(researcher_error()) :: {:error, researcher_error()}
  def error({error_type, _details} = reason)
      when error_type in @valid_errors do
    {:error, reason}
  end

  def error(reason) when reason in @valid_errors do
    {:error, reason}
  end

  def error(reason) do
    raise ArgumentError, "Unexpected error reason: #{inspect(reason)}"
  end
end
