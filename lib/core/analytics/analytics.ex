defmodule Core.Analytics do
  @moduledoc """
  Module for analytics.
  """

  import Ecto.Query
  alias Core.Repo
  alias Core.Analytics.LeadGeneration

  def get_session_analytics(tenant_id, time_range \\ :hour) do
    now = DateTime.utc_now()

    case time_range do
      :hour ->
        # Past 24 hours from now
        start_time = DateTime.add(now, -24, :hour)

        from(lg in LeadGeneration,
          where: lg.tenant_id == ^tenant_id,
          where: lg.bucket_start_at >= ^start_time,
          where: lg.bucket_start_at <= ^now,
          order_by: [desc: lg.bucket_start_at]
        )
        |> Repo.all()

      :day ->
        # Past 7 days aggregated by day
        start_time = DateTime.add(now, -6, :day)

        from(lg in LeadGeneration,
          where: lg.tenant_id == ^tenant_id,
          where: lg.bucket_start_at >= ^start_time,
          where: lg.bucket_start_at <= ^now,
          group_by: fragment("DATE(?)", lg.bucket_start_at),
          order_by: [desc: fragment("DATE(?)", lg.bucket_start_at)],
          select: %{
            bucket_start_at: fragment("DATE(?)", lg.bucket_start_at),
            sessions: sum(lg.sessions),
            identified_sessions: sum(lg.identified_sessions),
            icp_fit_sessions: sum(lg.icp_fit_sessions),
            unique_companies: sum(lg.unique_companies),
            new_icp_fit_leads: sum(lg.new_icp_fit_leads)
          }
        )
        |> Repo.all()

      :week ->
        # Past 4 weeks aggregated by week
        start_time = DateTime.add(now, -21, :day)

        from(lg in LeadGeneration,
          where: lg.tenant_id == ^tenant_id,
          where: lg.bucket_start_at >= ^start_time,
          where: lg.bucket_start_at <= ^now,
          group_by: fragment("DATE(DATE_TRUNC('week', ?))", lg.bucket_start_at),
          order_by: [
            desc: fragment("DATE(DATE_TRUNC('week', ?))", lg.bucket_start_at)
          ],
          select: %{
            bucket_start_at:
              fragment("DATE(DATE_TRUNC('week', ?))", lg.bucket_start_at),
            sessions: sum(lg.sessions),
            identified_sessions: sum(lg.identified_sessions),
            icp_fit_sessions: sum(lg.icp_fit_sessions),
            unique_companies: sum(lg.unique_companies),
            new_icp_fit_leads: sum(lg.new_icp_fit_leads)
          }
        )
        |> Repo.all()

      :month ->
        # Past 3 months aggregated by month
        start_time = DateTime.add(now, -90, :day)

        from(lg in LeadGeneration,
          where: lg.tenant_id == ^tenant_id,
          where: lg.bucket_start_at >= ^start_time,
          where: lg.bucket_start_at <= ^now,
          group_by:
            fragment("DATE(DATE_TRUNC('month', ?))", lg.bucket_start_at),
          order_by: [
            desc: fragment("DATE(DATE_TRUNC('month', ?))", lg.bucket_start_at)
          ],
          select: %{
            bucket_start_at:
              fragment("DATE(DATE_TRUNC('month', ?))", lg.bucket_start_at),
            sessions: sum(lg.sessions),
            identified_sessions: sum(lg.identified_sessions),
            icp_fit_sessions: sum(lg.icp_fit_sessions),
            unique_companies: sum(lg.unique_companies),
            new_icp_fit_leads: sum(lg.new_icp_fit_leads)
          }
        )
        |> Repo.all()
    end
  end
end
