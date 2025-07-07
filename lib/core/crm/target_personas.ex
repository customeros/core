defmodule Core.Crm.TargetPersonas do
  @moduledoc """
  Manages target personas for CRM contacts.

  This module handles the creation and management of target personas from LinkedIn
  profiles. It can create personas from LinkedIn URLs (both IDs and aliases),
  filter active contacts, and queue LinkedIn profiles for processing when direct
  creation fails.
  """

  require Logger

  require OpenTelemetry.Tracer
  alias Core.Repo
  alias Core.Crm.Contacts
  alias Core.Utils.LinkedinParser
  alias Core.Crm.TargetPersonas.TargetPersona
  alias Core.Crm.TargetPersonas.TargetPersonaLinkedinQueues
  alias Core.Utils.Tracing
  alias Core.Auth.Tenants

  @err_persona_creation_failed {:error, :target_persona_creation_failed}
  @err_tenant_not_found {:error, :tenant_not_found}

  def create_from_linkedin(tenant_id, linkedin_url) do
    OpenTelemetry.Tracer.with_span "target_personas.create_from_linkedin" do
      OpenTelemetry.Tracer.set_attributes([
        {"param.tenant.id", tenant_id},
        {"param.linkedin_url", linkedin_url}
      ])

      case Tenants.get_tenant_by_id(tenant_id) do
        {:ok, _tenant} ->
          case LinkedinParser.parse_contact_url(linkedin_url) do
            {:ok, :id, id} ->
              create_from_linkedin_id(tenant_id, id)

            {:ok, :alias, alias} ->
              create_from_linkedin_alias(tenant_id, alias)

            {:error, reason} ->
              Tracing.error(reason, "Unable to create prospect from linkedin",
                tenant_id: tenant_id,
                linkedin_url: linkedin_url
              )

              {:error, reason}
          end

        {:error, :not_found} ->
          Tracing.error(
            :not_found,
            "Tenant not found for target persona creation",
            tenant_id: tenant_id,
            linkedin_url: linkedin_url
          )

          @err_tenant_not_found
      end
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
      |> Repo.insert(
        on_conflict: :nothing,
        conflict_target: [:tenant_id, :contact_id]
      )

    case result do
      {:ok, persona} when not is_nil(persona) ->
        # Trigger enrichment for the new target persona
        Task.start(fn ->
          case Contacts.start_email_and_phone_enrichment(contact_id) do
            {:ok, :enrichment_started} ->
              Logger.info("Started enrichment for target persona", %{
                tenant_id: tenant_id,
                contact_id: contact_id
              })

            {:error, reason} ->
              Logger.warning("Failed to start enrichment for target persona", %{
                tenant_id: tenant_id,
                contact_id: contact_id,
                reason: reason
              })
          end
        end)

        {:ok, persona}

      {:ok, nil} ->
        case get_persona(tenant_id, contact_id) do
          {:ok, persona} -> {:ok, persona}
          :not_found -> @err_persona_creation_failed
        end

      {:error, _changeset} ->
        Logger.error("Failed to create target persona", %{
          tenant_id: tenant_id,
          contact_id: contact_id
        })

        @err_persona_creation_failed
    end
  end

  def get_persona(tenant_id, contact_id) do
    case Repo.get_by(TargetPersona,
           tenant_id: tenant_id,
           contact_id: contact_id
         ) do
      nil -> :not_found
      persona -> {:ok, persona}
    end
  end

  defp filter_active_contacts(contacts) do
    Enum.filter(contacts, fn contact ->
      (is_nil(contact.job_ended_at) or
         DateTime.compare(contact.job_ended_at, DateTime.utc_now()) == :gt) and
        not is_nil(contact.company_id)
    end)
  end

  defp create_personas_for_contacts(contacts, tenant_id) do
    Enum.map(contacts, fn contact ->
      case create(tenant_id, contact.id) do
        {:ok, persona} ->
          persona

        {:error, _reason} ->
          case get_persona(tenant_id, contact.id) do
            {:ok, persona} -> persona
            :not_found -> nil
          end
      end
    end)
    |> Enum.filter(& &1)
  end

  defp create_from_linkedin_id(tenant_id, linkedin_id) do
    OpenTelemetry.Tracer.with_span "target_personas.create_from_linkedin_id" do
      OpenTelemetry.Tracer.set_attributes([
        {"param.tenant.id", tenant_id},
        {"param.linkedin_id", linkedin_id}
      ])

      case Contacts.get_contacts_by_linkedin_id(linkedin_id) do
        {:ok, contacts} ->
          personas =
            contacts
            |> filter_active_contacts()
            |> create_personas_for_contacts(tenant_id)

          {:ok, personas}

        :not_found ->
          create_contacts_and_personas_from_linkedin_id(tenant_id, linkedin_id)
      end
    end
  end

  defp create_from_linkedin_alias(tenant_id, alias) do
    OpenTelemetry.Tracer.with_span "target_personas.create_from_linkedin_alias" do
      OpenTelemetry.Tracer.set_attributes([
        {"param.tenant.id", tenant_id},
        {"param.linkedin_alias", alias}
      ])

      case Contacts.get_contacts_by_linkedin_alias(alias) do
        {:ok, contacts} ->
          personas =
            contacts
            |> filter_active_contacts()
            |> create_personas_for_contacts(tenant_id)

          {:ok, personas}

        :not_found ->
          create_contacts_and_personas_from_linkedin_alias(tenant_id, alias)
      end
    end
  end

  defp create_contacts_and_personas_from_linkedin_id(tenant_id, linkedin_id) do
    case Contacts.create_contacts_by_linkedin_id(linkedin_id) do
      {:ok, contacts} ->
        personas =
          contacts
          |> filter_active_contacts()
          |> create_personas_for_contacts(tenant_id)

        {:ok, personas}

      {:error, reason} ->
        TargetPersonaLinkedinQueues.add_record(
          tenant_id,
          "https://www.linkedin.com/in/#{linkedin_id}"
        )

        {:error, reason}
    end
  end

  defp create_contacts_and_personas_from_linkedin_alias(tenant_id, alias) do
    case Contacts.create_contacts_by_linkedin_alias(alias) do
      {:ok, contacts} ->
        personas =
          contacts
          |> filter_active_contacts()
          |> create_personas_for_contacts(tenant_id)

        {:ok, personas}

      {:error, reason} ->
        TargetPersonaLinkedinQueues.add_record(tenant_id, alias)

        {:error, reason}
    end
  end
end
