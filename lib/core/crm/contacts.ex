defmodule Core.Crm.Contacts do
  @moduledoc """
  Manages contact data and operations.
  """
  require Logger
  require OpenTelemetry.Tracer
  import Ecto.Query

  alias Core.Repo
  alias Core.Crm.Contacts.Contact
  alias Core.ScrapinContacts

  # @err_undeliverable {:error, "email address is undeliverable"}
  @err_contact_creation_failed {:error, "contact creation failed"}

  def create_contacts_by_linkedin_alias(alias) do
    linkedin_url = "https://www.linkedin.com/in/#{alias}"
    create_contacts_from_linkedin_url(linkedin_url)
  end

  def create_contacts_by_linkedin_id(linkedin_id) do
    linkedin_url = "https://www.linkedin.com/in/#{linkedin_id}"
    create_contacts_from_linkedin_url(linkedin_url)
  end

  defp create_contacts_from_linkedin_url(linkedin_url) do
    OpenTelemetry.Tracer.with_span "contacts.create_contacts_from_linkedin_url" do
      OpenTelemetry.Tracer.set_attributes([
        {"param.linkedin_url", linkedin_url}
      ])

    case ScrapinContacts.profile_contact_with_scrapin(linkedin_url) do
      {:ok, contact_details} ->
        create_contacts_from_details(contact_details)

      {:error, :not_found} ->
        Logger.warning("No contact found for LinkedIn URL", %{linkedin_url: linkedin_url})
        {:error, :not_found}

      {:error, reason} ->
        Logger.error("Failed to fetch contact from LinkedIn", %{
          linkedin_url: linkedin_url,
          reason: reason
        })
        {:error, reason}
    end
  end
  end

  defp create_contacts_from_details(contact_details) do
    case contact_details.positions do
      %{position_history: positions} when is_list(positions) and length(positions) > 0 ->
        # Get common fields from person details
        common_fields = extract_common_fields(contact_details)

        # Process each position and create/update contacts
        results = Enum.map(positions, fn position ->
          create_or_update_contact_for_position(common_fields, position)
        end)

        # Return successful results
        successful_results = Enum.filter(results, fn
          {:ok, _contact} -> true
          {:error, _reason} -> false
        end)

        case successful_results do
          [] ->
            Logger.error("Failed to create any contacts from LinkedIn positions")
            {:error, :no_contacts_created}
          contacts ->
            {:ok, Enum.map(contacts, fn {:ok, contact} -> contact end)}
        end

      _ ->
        Logger.warning("No positions found in LinkedIn contact details")
        {:error, :no_positions_found}
    end
  end

  defp extract_common_fields(contact_details) do
    %{
      first_name: contact_details.first_name,
      last_name: contact_details.last_name,
      full_name: build_full_name(contact_details.first_name, contact_details.last_name),
      linkedin_id: contact_details.linked_in_identifier,
      linkedin_alias: contact_details.public_identifier,
      # avatar_key: contact_details.photo_url,
      location: contact_details.location,
      headline: contact_details.headline,
      summary: contact_details.summary
    }
  end

  defp build_full_name(first_name, last_name) do
    case {first_name, last_name} do
      {nil, nil} -> nil
      {first, nil} -> first
      {nil, last} -> last
      {first, last} -> "#{first} #{last}"
    end
  end

  defp create_or_update_contact_for_position(common_fields, position) do
    # Extract position-specific fields
    position_fields = extract_position_fields(position)

    # Combine common and position fields
    contact_attrs = Map.merge(common_fields, position_fields)

    # Check if contact already exists with same linkedin_id and linkedin_company_id
    case find_existing_contact_by_linkedin_id_and_company_id(contact_attrs.linkedin_id, contact_attrs.linkedin_company_id) do
      nil ->
        create_contact(%Contact{}, contact_attrs)

      existing_contact ->
        if should_update_contact(existing_contact, contact_attrs) do
          update_contact_with_position(existing_contact, contact_attrs)
        else
          {:ok, existing_contact}
        end
    end
  end

  defp extract_position_fields(position) do
    %{
      job_title: position.title,
      linkedin_company_id: position.linked_in_id,
      job_description: position.description,
      job_started_at: parse_start_date(position.start_end_date),
      job_ended_at: parse_end_date(position.start_end_date)
    }
  end

  defp parse_start_date(start_end_date) when is_map(start_end_date) do
    case Map.get(start_end_date, :start_date) do
      nil -> nil
      date_map when is_map(date_map) -> parse_date_map(date_map)
      _ -> nil
    end
  end

  defp parse_start_date(_), do: nil

  defp parse_end_date(start_end_date) when is_map(start_end_date) do
    case Map.get(start_end_date, :end_date) do
      nil -> nil
      date_map when is_map(date_map) -> parse_date_map(date_map)
      _ -> nil
    end
  end

  defp parse_end_date(_), do: nil

  defp parse_date_map(%{year: year, month: month, day: day})
       when is_integer(year) and is_integer(month) and is_integer(day) do
    case Date.new(year, month, day) do
      {:ok, date} -> DateTime.new(date, ~T[00:00:00], "Etc/UTC") |> elem(1)
      _ -> nil
    end
  end

  defp parse_date_map(%{year: year, month: month})
       when is_integer(year) and is_integer(month) do
    case Date.new(year, month, 1) do
      {:ok, date} -> DateTime.new(date, ~T[00:00:00], "Etc/UTC") |> elem(1)
      _ -> nil
    end
  end

  defp parse_date_map(%{year: year}) when is_integer(year) do
    case Date.new(year, 1, 1) do
      {:ok, date} -> DateTime.new(date, ~T[00:00:00], "Etc/UTC") |> elem(1)
      _ -> nil
    end
  end

  defp parse_date_map(_), do: nil

  defp find_existing_contact_by_linkedin_id_and_company_id(linkedin_id, linkedin_company_id) do
    Repo.get_by(Contact,
      linkedin_id: linkedin_id,
      linkedin_company_id: linkedin_company_id
    )
  end

  defp should_update_contact(existing_contact, new_contact_attrs) do
    # Priority rules:
    # 1. If job_ended_at is missing, that one wins
    # 2. If same value or multiple nil, most recent started_at wins

    existing_ended = existing_contact.job_ended_at
    new_ended = new_contact_attrs.job_ended_at
    existing_started = existing_contact.job_started_at
    new_started = new_contact_attrs.job_started_at

    cond do
      # Rule 1: If existing has end date but new doesn't, new wins
      not is_nil(existing_ended) and is_nil(new_ended) ->
        true

      # Rule 1: If new has end date but existing doesn't, existing wins
      is_nil(existing_ended) and not is_nil(new_ended) ->
        false

      # Rule 2: If both have same end date status, compare start dates
      is_nil(existing_ended) == is_nil(new_ended) ->
        case {existing_started, new_started} do
          {nil, nil} -> false  # Keep existing if both have no start date
          {nil, _} -> true     # New wins if existing has no start date
          {_, nil} -> false    # Existing wins if new has no start date
          {existing, new} ->
            # Most recent start date wins
            DateTime.compare(new, existing) == :gt
        end

      # Default: keep existing
      true -> false
    end
  end

  defp update_contact_with_position(existing_contact, contact_attrs) do
    update_contact_field(
      existing_contact.id,
      contact_attrs,
      "position data"
    )
  end

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

  def get_contacts_by_linkedin_id(linkedin_id) do
    contacts = Repo.all(from c in Contact, where: c.linkedin_id == ^linkedin_id)

    case contacts do
      [] -> :not_found
      contacts -> {:ok, contacts}
    end
  end

  def get_contacts_by_linkedin_alias(alias) do
    contacts = Repo.all(from c in Contact, where: c.linkedin_alias == ^alias)

    case contacts do
      [] -> :not_found
      contacts -> {:ok, contacts}
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
