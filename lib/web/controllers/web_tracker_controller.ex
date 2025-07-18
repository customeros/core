defmodule Web.WebTrackerController do
  use Web, :controller
  require Logger
  require OpenTelemetry.Tracer

  alias Core.WebTracker.OriginValidator
  alias Core.WebTracker.OriginTenantMapper
  alias Core.WebTracker.Events
  alias Core.WebTracker.BotDetector
  alias Core.WebTracker.IPProfiler
  alias Core.Utils.Tracing

  plug Web.Plugs.ValidateWebTrackerHeaders when action in [:create]

  def create(conn, params) do
    OpenTelemetry.Tracer.with_span "web_tracker_controller.create" do
      OpenTelemetry.Tracer.set_attributes([
        {"param.origin", params["origin"]},
        {"param.visitor_id", params["visitorId"]}
      ])

      with :ok <- validate_origin(params["origin"]),
           {:ok, _} <- validate_visitor_id(params["visitorId"]),
           :ok <- validate_ip_safety(params["ip"]),
           :ok <- validate_bot_detection(params) do
        case Events.create(params) do
          {:ok, _event} ->
            Tracing.ok()

            conn
            |> put_status(:accepted)
            |> json(%{accepted: true})

          {:error, changeset} ->
            Tracing.error(changeset.errors, "Web-tracker event creation failed")

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
          OpenTelemetry.Tracer.set_attributes([
            {"result.error", "Origin is ignored"}
          ])

          conn
          |> put_status(:forbidden)
          |> json(%{
            error: "forbidden",
            details: %{origin: "Origin is ignored"}
          })

        {:error, :origin_not_configured} ->
          OpenTelemetry.Tracer.set_attributes([
            {"result.error", "Origin not configured"}
          ])

          conn
          |> put_status(:forbidden)
          |> json(%{
            error: "forbidden",
            details: %{origin: "Origin not configured"}
          })

        {:error, :missing_visitor_id} ->
          OpenTelemetry.Tracer.set_attributes([
            {"result.error", "Visitor ID is required"}
          ])

          conn
          |> put_status(:bad_request)
          |> json(%{
            error: "bad_request",
            details: %{visitor_id: "Visitor ID is required"}
          })

        {:error, :ip_is_threat} ->
          OpenTelemetry.Tracer.set_attributes([
            {"result.error", "IP is flagged as threat"}
          ])

          Tracing.warning(
            :ip_is_threat,
            "Blocking event creation - IP is flagged as threat",
            ip: params["ip"]
          )

          conn
          |> put_status(:forbidden)
          |> json(%{error: "forbidden"})

        {:error, {:bot_detected, confidence}} ->
          OpenTelemetry.Tracer.set_attributes([
            {"result.error", "Bot detected"},
            {"result.bot_confidence", confidence}
          ])

          Tracing.warning(
            :bot_detected,
            "Blocking event creation - Bot detected",
            user_agent: params["userAgent"],
            confidence: confidence
          )

          conn
          |> put_status(:forbidden)
          |> json(%{error: "forbidden"})
      end
    end
  end

  def bot_detect(conn, %{"ip" => ip}) do
    OpenTelemetry.Tracer.with_span "web_tracker_controller.bot_detect" do
      user_agent = get_req_header(conn, "user-agent") |> List.first() || ""
      origin = get_req_header(conn, "origin") |> List.first() || ""
      referrer = get_req_header(conn, "referrer") |> List.first() || ""

      OpenTelemetry.Tracer.set_attributes([
        {"http.method", "GET"},
        {"http.route", "/v1/events/bot-detect"},
        {"http.header.user-agent", user_agent},
        {"http.header.origin", origin},
        {"http.header.ip", ip},
        {"http.header.referrer", referrer}
      ])

      # Call our custom bot detection
      bot_result = BotDetector.detect_bot(user_agent, ip, origin, referrer)

      case bot_result do
        {:ok, bot_response} ->
          conn
          |> put_status(:ok)
          |> json(bot_response)

        {:error, reason} ->
          Tracing.error(reason)

          conn
          |> put_status(:internal_server_error)
          |> json(%{error: "bot_detection_failed", details: reason})
      end
    end
  end

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

  defp validate_ip_safety(ip) when is_binary(ip) and ip != "" do
    case IPProfiler.get_ip_data(ip) do
      {:ok, ip_data} ->
        if ip_data.is_threat do
          {:error, :ip_is_threat}
        else
          :ok
        end

      {:error, reason} ->
        Tracing.warning(
          reason,
          "IP validation failed, allowing event creation",
          ip: ip
        )

        # Allow event creation if IP validation fails
        :ok
    end
  end

  defp validate_ip_safety(_), do: :ok

  defp validate_bot_detection(params) do
    user_agent = params["userAgent"] || ""
    ip = params["ip"] || ""
    origin = params["origin"] || ""
    referrer = params["referrer"] || ""

    case BotDetector.detect_bot(user_agent, ip, origin, referrer) do
      {:ok, %{bot: true, confidence: confidence}} ->
        {:error, {:bot_detected, confidence}}

      {:ok, %{bot: false}} ->
        :ok

      {:error, reason} ->
        Tracing.warning(
          reason,
          "Bot detection failed, allowing event creation",
          user_agent: user_agent,
          ip: ip
        )

        :ok
    end
  end

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
