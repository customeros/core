defmodule Core.Crm.Contacts do
  @moduledoc """
  Manages contact data and operations.
  """
  require Logger

  alias Core.Repo
  alias Core.Crm.Contacts.Contact

  @err_contact_creation_failed {:error, "contact creation failed"}

  def create_contact(%Contact{} = contact, attrs \\ %{}) do
    result =
      contact
      |> Contact.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, record} ->
        {:ok, record}

      {:error, _changeset} ->
        Logger.error("Failed to create contact", contact)

        @err_contact_creation_failed
    end
  end

  def update_business_email(business_email, status, contact_id) do
    update_contact_field(
      contact_id,
      %{business_email: business_email, business_email_status: status},
      "business email"
    )
  end

  def update_mobile_phone(mobile_phone, contact_id) do
    update_contact_field(
      contact_id,
      %{mobile_phone: mobile_phone},
      "mobile phone"
    )
  end

  defp update_contact_field(contact_id, attrs, field_name) do
    case Repo.get(Contact, contact_id) do
      nil ->
        {:error, "Contact not found"}

      contact ->
        contact
        |> Contact.changeset(attrs)
        |> Repo.update()
        |> case do
          {:ok, updated_contact} ->
            Logger.info("Updated contact #{field_name}", %{
              contact_id: contact_id,
              changes: attrs
            })

            {:ok, updated_contact}

          {:error, changeset} ->
            Logger.error("Failed to update contact #{field_name}", %{
              contact_id: contact_id,
              errors: changeset.errors
            })

            {:error, "Failed to update #{field_name}"}
        end
    end
  end
end
