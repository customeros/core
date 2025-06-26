defmodule Web.WebTrackerController do
  use Web, :controller
  require Logger
  require OpenTelemetry.Tracer

  alias Core.WebTracker.OriginValidator
  alias Core.WebTracker.OriginTenantMapper
  alias Core.WebTracker.Events

  plug Web.Plugs.ValidateWebTrackerHeaders when action in [:create]

  def create(conn, params) do
    # Early validation of origin and visitor_id
    with :ok <- validate_origin(params["origin"]),
         {:ok, _} <- validate_visitor_id(params["visitorId"]) do
      case Events.create(params) do
        {:ok, _event} ->
          conn
          |> put_status(:accepted)
          |> json(%{accepted: true})

        {:error, changeset} ->
          errors =
            changeset.errors
            |> Enum.map(fn {field, {message, _opts}} -> {field, message} end)
            |> Enum.into(%{})

          status = determine_error_status(errors)

          conn
          |> put_status(status)
          |> json(%{error: "bad_request", details: errors})
      end
    else
      {:error, :origin_ignored} ->
        conn
        |> put_status(:forbidden)
        |> json(%{error: "forbidden", details: %{origin: "Origin is ignored"}})

      {:error, :origin_not_configured} ->
        conn
        |> put_status(:forbidden)
        |> json(%{
          error: "forbidden",
          details: %{origin: "Origin not configured"}
        })

      {:error, :missing_visitor_id} ->
        conn
        |> put_status(:bad_request)
        |> json(%{
          error: "bad_request",
          details: %{visitor_id: "Visitor ID is required"}
        })
    end
  end

  @spec validate_origin(String.t()) :: :ok | {:error, atom()}
  defp validate_origin(origin) when is_binary(origin) and origin != "" do
    cond do
      OriginValidator.should_ignore_origin?(origin) ->
        {:error, :origin_ignored}

      not OriginTenantMapper.whitelisted?(origin) ->
        {:error, :origin_not_configured}

      true ->
        :ok
    end
  end

  defp validate_origin(_), do: {:error, :origin_not_configured}

  @spec validate_visitor_id(String.t() | nil) ::
          {:ok, String.t()} | {:error, :missing_visitor_id}
  defp validate_visitor_id(visitor_id)
       when is_binary(visitor_id) and visitor_id != "",
       do: {:ok, visitor_id}

  defp validate_visitor_id(_), do: {:error, :missing_visitor_id}

  @spec determine_error_status(map()) :: :bad_request | :forbidden
  defp determine_error_status(errors) do
    # Check if any of the errors are security-related (bot, suspicious referrer)
    has_security_error =
      Enum.any?(errors, fn {field, message} ->
        field in [:user_agent, :referrer] and
          String.contains?(message, ["bot", "suspicious", "not allowed"])
      end)

    if has_security_error, do: :forbidden, else: :bad_request
  end
end
