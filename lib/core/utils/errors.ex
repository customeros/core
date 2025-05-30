defmodule Core.Utils.Errors do
  @moduledoc """
  Common error definitions for the utils package
  """

  # Define valid errors as module attributes
  @domain_errors [
    :invalid_domain,
    :domain_not_provided,
    :unable_to_normalize_domain,
    :no_primary_domain
  ]
  @dns_errors [
    :dns_lookup_failed,
    :no_records_found,
    :invalid_domain,
    :cannot_resolve_domain
  ]
  @email_errors [:invalid_email, :email_not_provided]
  @url_errors [:invalid_url, :url_not_provided, :unable_to_expand_url]
  @data_errors [:not_found, :update_failed, :insert_failed]

  @valid_errors @domain_errors ++ @dns_errors ++ @email_errors ++ @url_errors ++ @data_errors

  # Error types
  @type domain_error ::
          :invalid_domain
          | :domain_not_provided
          | :unable_to_normalize_domain
          | :no_primary_domain
  @type dns_error ::
          :dns_lookup_failed
          | :no_records_found
          | :invalid_domain
          | :cannot_resolve_domain
  @type email_error :: :invalid_email | :email_not_provided
  @type url_error :: :invalid_url | :url_not_provided | :unable_to_expand_url
  @type data_error :: :not_found | :update_failed| :insert_failed
  @type util_error :: domain_error() | dns_error() | email_error() | url_error()

  @doc """
  Creates a standardized error tuple.
  """
  @spec error(util_error()) :: {:error, util_error()}
  def error(reason) when reason in @valid_errors do
    {:error, reason}
  end
end
