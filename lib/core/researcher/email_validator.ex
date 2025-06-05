defmodule Core.Researcher.EmailValidator do
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
end
