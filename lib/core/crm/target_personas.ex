defmodule Core.Crm.TargetPersonas do
  require Logger

  alias Core.Repo
  alias Core.Crm.Contacts
  alias Core.Utils.LinkedinParser
  alias Core.Crm.TargetPersonas.TargetPersona

  @err_persona_creation_failed {:error, "target persona creation failed"}

  def create_from_linkedin(tenant_id, linkedin_url) do
    case LinkedinParser.parse_contact_url(linkedin_url) do
      {:ok, :id, id} ->
        create_from_linkedin_id(tenant_id, id)

      {:ok, :alias, alias} ->
        create_from_linkedin_alias(tenant_id, alias)

      {:error, reason} ->
        Logger.error("Unable to create prospect from linkedin", %{
          tenant_id: tenant_id,
          linkedin_url: linkedin_url
        })

        {:error, reason}
    end
  end

  def create(tenant_id, contact_id) do
    attrs = %{
      tenant_id: tenant_id,
      contact_id: contact_id
    }

    result =
      %TargetPersona{}
      |> TargetPersona.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, persona} ->
        {:ok, persona}

      {:error, _changeset} ->
        Logger.error("Failed to create target persona", %{
          tenant_id: tenant_id,
          contact_id: contact_id
        })

        @err_persona_creation_failed
    end
  end

  defp create_from_linkedin_id(tenant_id, linkedin_id) do
    case Contacts.get_contact_by_linkedin_id(linkedin_id) do
      {:ok, contact} ->
        create(tenant_id, contact.id)

      :not_found ->
        create_contact_and_persona_from_linkedin_id(tenant_id, linkedin_id)
    end
  end

  defp create_from_linkedin_alias(tenant_id, alias) do
    case Contacts.get_contact_by_linkedin_alias(alias) do
      {:ok, contact} ->
        create(tenant_id, contact.id)

      :not_found ->
        create_contact_and_persona_from_linkedin_alias(tenant_id, alias)
    end
  end

  defp create_contact_and_persona_from_linkedin_id(tenant_id, linkedin_id) do
    case Contacts.create_contact_by_linkedin_id(linkedin_id) do
      {:ok, contact} ->
        create(tenant_id, contact.id)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp create_contact_and_persona_from_linkedin_alias(tenant_id, alias) do
    case Contacts.create_contact_by_linkedin_alias(alias) do
      {:ok, contact} ->
        create(tenant_id, contact.id)

      {:error, reason} ->
        {:error, reason}
    end
  end
end
