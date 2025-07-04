defmodule Core.Crm.TargetPersonas.TargetPersonaLinkedinQueues do
  alias Core.Crm.TargetPersonas.TargetPersonaLinkedinQueue
  alias Core.Repo
  import Ecto.Query

  def add_record(tenant_id, linkedin_url)
      when is_binary(tenant_id) and is_binary(linkedin_url) do
    case get_record_by_tenant_and_linkedin(tenant_id, linkedin_url) do
      nil ->
        %TargetPersonaLinkedinQueue{}
        |> TargetPersonaLinkedinQueue.changeset(%{
          tenant_id: tenant_id,
          linkedin_url: linkedin_url
        })
        |> Repo.insert()

      _existing_record ->
        {:ok, nil}
    end
  end

  def get_record_by_tenant_and_linkedin(tenant_id, linkedin_url) do
    TargetPersonaLinkedinQueue
    |> where([q], q.tenant_id == ^tenant_id and q.linkedin_url == ^linkedin_url)
    |> Repo.one()
  end

  def update_attempt(record_id) do
    TargetPersonaLinkedinQueue
    |> Repo.get(record_id)
    |> case do
      nil ->
        {:error, :not_found}

      record ->
        record
        |> TargetPersonaLinkedinQueue.changeset(%{
          attempts: record.attempts + 1,
          last_attempt_at: DateTime.utc_now()
        })
        |> Repo.update()
    end
  end

  def mark_completed(record_id) do
    TargetPersonaLinkedinQueue
    |> Repo.get(record_id)
    |> case do
      nil ->
        {:error, :not_found}

      record ->
        record
        |> TargetPersonaLinkedinQueue.changeset(%{
          completed_at: DateTime.utc_now()
        })
        |> Repo.update()
    end
  end
end
