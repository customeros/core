defmodule Web.WebTrackerController do
  use Web, :controller
  require Logger
  require OpenTelemetry.Tracer

  alias Core.WebTracker
  alias Core.WebTracker.OriginValidator
  alias Core.WebTracker.OriginTenantMapper
  alias Core.WebTracker.WebTracker.Event
  alias Core.Utils.Tracing

  plug Web.Plugs.ValidateWebTrackerHeaders when action in [:create]

  @spec create(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def create(conn, params) do
    OpenTelemetry.Tracer.with_span "web_tracker.create_event" do
      # Add request attributes to the span
      OpenTelemetry.Tracer.set_attributes([
        {"http.method", "POST"},
        {"http.route", "/v1/events"},
        {"http.target", "/v1/events"},
        {"http.event.visitor.id", Map.get(params, "visitorId")},
        {"http.event.type", Map.get(params, "eventType")},
        {"http.header.origin", conn.assigns.origin},
        {"http.header.referer", conn.assigns.referer},
        {"http.header.user-agent", conn.assigns.user_agent}
      ])

      # Header values used only for validation
      header_origin = conn.assigns.origin
      header_user_agent = conn.assigns.user_agent
      header_referrer = conn.assigns.referer

      visitor_id = Map.get(params, "visitorId")

      # If referrer is not provided in the body, use the header value
      params =
        if Map.get(params, "referrer") in [nil, ""] do
          Map.put(params, "referrer", header_referrer)
        else
          params
        end

      with {:ok, visitor_id} <- validate_visitor_id(visitor_id),
           :ok <- validate_origin(header_origin),
           {:ok, tenant} <-
             OriginTenantMapper.get_tenant_for_origin(header_origin),
           :ok <- WebTracker.check_bot(header_user_agent),
           :ok <- WebTracker.check_suspicious(header_referrer),
           # Create event params with body values
           {:ok, event_params} <-
             Event.new(
               Map.merge(params, %{
                 "tenant" => tenant,
                 "visitor_id" => visitor_id
               })
             ) do
        case WebTracker.process_new_event(event_params) do
          {:ok, result} ->
            Tracing.ok()

            conn
            |> put_status(:accepted)
            |> json(%{accepted: true, session_id: result.session_id})

          {:error, :forbidden, _message} ->
            Tracing.error(:forbidden)

            conn
            |> put_status(:forbidden)
            |> json(%{error: "forbidden", details: "request blocked"})

          {:error, :bad_request, message} ->
            Tracing.error(:bad_request)

            conn
            |> put_status(:bad_request)
            |> json(%{error: "bad_request", details: message})

          {:error, _status, _message} ->
            Tracing.error(:internal_server_error)

            conn
            |> put_status(:internal_server_error)
            |> json(%{
              error: "internal_server_error",
              details: "something went wrong"
            })
        end
      else
        {:error, :missing_visitor_id} ->
          Tracing.error(:missing_visitor_id)

          conn
          |> put_status(:bad_request)
          |> json(%{error: "bad_request", details: "missing visitor_id"})

        {:error, :bot} ->
          Tracing.error("bot_detected")

          conn
          |> put_status(:forbidden)
          |> json(%{error: "forbidden", details: "bot detected"})

        {:error, :suspicious} ->
          Tracing.error("suspicious_referrer")

          conn
          |> put_status(:forbidden)
          |> json(%{error: "forbidden", details: "suspicious referrer"})

        {:error, :origin_ignored} ->
          Tracing.error(:origin_ignored)

          conn
          |> put_status(:forbidden)
          |> json(%{error: "forbidden", details: "origin explicitly ignored"})

        {:error, :origin_not_configured} ->
          Tracing.error(:origin_not_configured)

          conn
          |> put_status(:forbidden)
          |> json(%{error: "forbidden", details: "origin not configured"})

        {:error, reason} when is_binary(reason) ->
          Tracing.error(reason)

          conn
          |> put_status(:bad_request)
          |> json(%{error: "bad_request", details: reason})
      end
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
end
