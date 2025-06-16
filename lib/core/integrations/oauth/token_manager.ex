defmodule Core.Integrations.OAuth.TokenManager do
  @moduledoc """
  Manages OAuth token refresh operations.

  This module provides functions for:
  - Automatically refreshing tokens before they expire
  - Retrying failed refresh attempts with exponential backoff
  - Monitoring token refresh operations
  """

  require Logger
  alias Core.Integrations.{Connection, Connections}
  alias Core.Integrations.Registry

  @max_retries 3
  # 1 second
  @base_delay 1000
  # 30 seconds
  @max_delay 30000

  @doc """
  Ensures a token is valid, refreshing it if necessary.

  This function:
  1. Checks if the token is expired or about to expire
  2. Attempts to refresh if needed
  3. Retries failed refreshes with exponential backoff
  4. Updates the connection with new tokens

  ## Parameters
    - connection - The integration connection to check/refresh

  ## Returns
    - `{:ok, Connection.t()}` - The connection with valid tokens
    - `{:error, reason}` - Error reason if refresh failed
  """
  def ensure_valid_token(%Connection{} = connection) do
    with :ok <- validate_token_timing(connection),
         {:ok, oauth} <- Registry.get_oauth(connection.provider),
         {:ok, refreshed} <- refresh_with_retry(oauth, connection, 0) do
      {:ok, refreshed}
    end
  end

  @doc """
  Checks if a token needs refresh based on its expiration time.

  Returns:
  - `:ok` if token is valid and doesn't need refresh
  - `:refresh_needed` if token is expired or about to expire
  - `{:error, reason}` if token is invalid
  """
  def validate_token_timing(%Connection{} = connection) do
    now = DateTime.utc_now()
    expires_at = connection.expires_at

    cond do
      is_nil(expires_at) ->
        {:error, :no_expiration_time}

      DateTime.compare(expires_at, now) == :lt ->
        :refresh_needed

      # Refresh if token expires in less than 5 minutes
      DateTime.diff(expires_at, now) < 300 ->
        :refresh_needed

      true ->
        :ok
    end
  end

  # Private functions

  defp refresh_with_retry(oauth, connection, attempt)
       when attempt < @max_retries do
    case oauth.refresh_token(connection) do
      {:ok, refreshed} ->
        log_refresh_success(connection, attempt)
        {:ok, refreshed}

      {:error, reason} ->
        log_refresh_failure(connection, reason, attempt)
        delay = calculate_delay(attempt)

        Logger.info(
          "Retrying token refresh for #{connection.id} in #{delay}ms (attempt #{attempt + 1})"
        )

        Process.sleep(delay)
        refresh_with_retry(oauth, connection, attempt + 1)
    end
  end

  defp refresh_with_retry(_oauth, connection, attempt) do
    log_refresh_max_retries(connection, attempt)

    Connections.update_connection(connection, %{
      status: :error,
      connection_error: "Token refresh failed after #{attempt} attempts"
    })

    {:error, :max_retries_exceeded}
  end

  defp calculate_delay(attempt) do
    delay = @base_delay * :math.pow(2, attempt)
    min(round(delay), @max_delay)
  end

  # Logging functions

  defp log_refresh_success(connection, attempt) do
    Logger.info("""
    Token refresh successful
    Connection: #{connection.id}
    Provider: #{connection.provider}
    Attempt: #{attempt + 1}
    """)
  end

  defp log_refresh_failure(connection, reason, attempt) do
    Logger.error("""
    Token refresh failed
    Connection: #{connection.id}
    Provider: #{connection.provider}
    Attempt: #{attempt + 1}
    Reason: #{inspect(reason)}
    """)
  end

  defp log_refresh_max_retries(connection, attempt) do
    Logger.error("""
    Token refresh failed after maximum retries
    Connection: #{connection.id}
    Provider: #{connection.provider}
    Total attempts: #{attempt}
    """)
  end
end
