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
        start_time = DateTime.add(now, -24, :hour)

        from(lg in LeadGeneration,
          where: lg.tenant_id == ^tenant_id,
          where: lg.bucket_start_at >= ^start_time,
          where: lg.bucket_start_at <= ^now,
          order_by: [desc: lg.bucket_start_at],
          select: %{
            bucket_start_at:
              fragment("TO_CHAR(?, 'HH24:MI')", lg.bucket_start_at),
            sessions: lg.sessions,
            identified_sessions: lg.identified_sessions,
            icp_fit_sessions: lg.icp_fit_sessions,
            unique_companies: lg.unique_companies,
            unique_new_companies: lg.unique_new_companies,
            new_icp_fit_leads: lg.new_icp_fit_leads
          }
        )
        |> Repo.all()

      :day ->
        # Past 7 days aggregated by day
        start_time = DateTime.add(now, -6, :day)

        from(lg in LeadGeneration,
          where: lg.tenant_id == ^tenant_id,
          where: lg.bucket_start_at >= ^start_time,
          where: lg.bucket_start_at <= ^now,
          group_by: fragment("TO_CHAR(?, 'DD-MM-YYYY')", lg.bucket_start_at),
          order_by: [
            desc: fragment("TO_CHAR(?, 'DD-MM-YYYY')", lg.bucket_start_at)
          ],
          select: %{
            bucket_start_at:
              fragment("TO_CHAR(?, 'DD-MM-YYYY')", lg.bucket_start_at),
            sessions: sum(lg.sessions),
            identified_sessions: sum(lg.identified_sessions),
            icp_fit_sessions: sum(lg.icp_fit_sessions),
            unique_companies: sum(lg.unique_companies),
            unique_new_companies: sum(lg.unique_new_companies),
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
          group_by:
            fragment(
              "TO_CHAR(DATE_TRUNC('week', ?), 'DD-MM-YYYY')",
              lg.bucket_start_at
            ),
          order_by: [
            desc:
              fragment(
                "TO_CHAR(DATE_TRUNC('week', ?), 'DD-MM-YYYY')",
                lg.bucket_start_at
              )
          ],
          select: %{
            bucket_start_at:
              fragment(
                "TO_CHAR(DATE_TRUNC('week', ?), 'DD-MM-YYYY')",
                lg.bucket_start_at
              ),
            sessions: sum(lg.sessions),
            identified_sessions: sum(lg.identified_sessions),
            icp_fit_sessions: sum(lg.icp_fit_sessions),
            unique_companies: sum(lg.unique_companies),
            unique_new_companies: sum(lg.unique_new_companies),
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
            fragment(
              "TO_CHAR(DATE_TRUNC('month', ?), 'DD-MM-YYYY')",
              lg.bucket_start_at
            ),
          order_by: [
            desc:
              fragment(
                "TO_CHAR(DATE_TRUNC('month', ?), 'DD-MM-YYYY')",
                lg.bucket_start_at
              )
          ],
          select: %{
            bucket_start_at:
              fragment(
                "TO_CHAR(DATE_TRUNC('month', ?), 'DD-MM-YYYY')",
                lg.bucket_start_at
              ),
            sessions: sum(lg.sessions),
            identified_sessions: sum(lg.identified_sessions),
            icp_fit_sessions: sum(lg.icp_fit_sessions),
            unique_companies: sum(lg.unique_companies),
            unique_new_companies: sum(lg.unique_new_companies),
            new_icp_fit_leads: sum(lg.new_icp_fit_leads)
          }
        )
        |> Repo.all()
    end
  end
end
