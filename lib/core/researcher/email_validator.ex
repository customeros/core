defmodule Core.Researcher.EmailValidator do
  @moduledoc """
  Provides email validation functionality using external validation services.

  This module serves as the main interface for email validation in the system,
  currently using the Mailsherpa service to validate email addresses. It handles:

  * Email format validation
  * Integration with external validation services
  * Logging of validation attempts and results
  * Error handling and reporting

  The validation process checks for:
  * Email format correctness
  * Domain validity
  * Mailbox existence
  * Disposable email detection
  * Role-based email detection
  """

  require Logger
  alias Core.Researcher.EmailValidator.Mailsherpa

  def validate_email(email) when is_binary(email) and byte_size(email) > 0 do
    Logger.metadata(module: __MODULE__, function: :validate_email, email: email)
    Logger.info("Starting email validation...")

    case Mailsherpa.validate_email(email) do
      {:ok, result} ->
        {:ok, result}

      {:error, reason} ->
        Logger.error("Email validation failed", reason: reason)
        {:error, reason}
    end
  end

  def best_email(%{did_you_mean: email}) when byte_size(email) > 0, do: email
  def best_email(%{clean_email: email}) when byte_size(email) > 0, do: email
  def best_email(_), do: :not_found

  def business_email?(%{valid_syntax: false}), do: false
  def business_email?(%{free_provider: true}), do: false
  def business_email?(%{role_based: true}), do: false
  def business_email?(%{disposable: true}), do: false
  def business_email?(%{is_system_generated: true}), do: false
  def business_email?(%{valid_syntax: true}), do: true
  def business_email?(_), do: false

  def email_type(%{role_based: true}), do: :other
  def email_type(%{disposable: true}), do: :other
  def email_type(%{is_system_generated: true}), do: :other
  def email_type(%{valid_syntax: true, free_provider: true}), do: :personal
  def email_type(%{valid_syntax: true, free_provider: false}), do: :business
  def email_type(_), do: :other

  def deliverable_status(%{deliverable: "false"}), do: :undeliverable
  def deliverable_status(%{deliverable: "true"}), do: :deliverable
  def deliverable_status(_), do: :unknown
end
