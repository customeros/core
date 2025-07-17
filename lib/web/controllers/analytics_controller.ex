defmodule Web.AnalyticsController do
  use Web, :controller

  alias Core.Analytics

  def index(conn, params) do
    %{tenant_id: tenant_id} = conn.assigns.current_user

    time_range =
      case params["time_range"] do
        "hour" -> :hour
        "day" -> :day
        "week" -> :week
        "month" -> :month
        _ -> :day
      end

    session_analytics =
      Analytics.get_session_analytics(
        tenant_id,
        time_range
      )

    conn
    |> assign_prop(:page_title, "Analytics | CustomerOS")
    |> assign_prop(:session_analytics, session_analytics)
    |> render_inertia("Analytics")
  end
end
