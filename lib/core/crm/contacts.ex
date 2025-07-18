defmodule Core.Crm.Contacts do
  @moduledoc """
  Manages contact data and operations.
  """
  require Logger
  require OpenTelemetry.Tracer
  import Ecto.Query

  alias Core.Crm.Companies
  alias Core.Crm.Contacts.{Contact, ContactsView}
  alias Core.Utils.{CalculateTimeInPosition, FormatLocation, StructUtils}
  alias Core.Repo
  alias Core.ScrapinContactDetails
  alias Core.ScrapinContactPosition
  alias Core.ScrapinContacts
  alias Core.Utils.Media.Images
  alias Core.Utils.Tracing
  alias Core.Crm.Contacts.Enricher.BetterContact
  alias Core.Crm.Contacts.Enricher.BetterContactRequest

  @err_contact_creation_failed {:error, "contact creation failed"}
  @linkedin_url_prefix "https://www.linkedin.com/in/"

  def create_contacts_by_linkedin_alias(linkedin_alias) do
    create_contacts_by_linkedin_url("#{@linkedin_url_prefix}#{linkedin_alias}")
  end

  def create_contacts_by_linkedin_id(linkedin_id) do
    create_contacts_by_linkedin_url("#{@linkedin_url_prefix}#{linkedin_id}")
  end

  defp create_contacts_by_linkedin_url(linkedin_url) do
    OpenTelemetry.Tracer.with_span "contacts.create_contacts_by_linkedin_url" do
      OpenTelemetry.Tracer.set_attributes([
        {"param.linkedin_url", linkedin_url}
      ])

      case ScrapinContacts.profile_contact_with_scrapin(linkedin_url) do
        {:ok, contact_details} ->
          create_contacts_from_scrapin_details(contact_details)

        {:error, :not_found} ->
          Logger.warning("No contact found for LinkedIn URL", %{
            linkedin_url: linkedin_url
          })

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

  defp create_contacts_from_scrapin_details(
         %ScrapinContactDetails{} = scrapin_contact_details
       ) do
    case scrapin_contact_details.positions do
      %{position_history: positions}
      when is_list(positions) and length(positions) > 0 ->
        common_fields = extract_common_fields(scrapin_contact_details)

        results =
          Enum.map(positions, fn position ->
            create_or_update_contact_for_position(common_fields, position)
          end)

        # Return successful results
        successful_results =
          Enum.filter(results, fn
            {:ok, _contact} -> true
            {:error, _reason} -> false
          end)

        case successful_results do
          [] ->
            Logger.error(
              "Failed to create any contacts from LinkedIn positions"
            )

            {:error, :no_contacts_created}

          contacts ->
            created_contacts =
              Enum.map(contacts, fn {:ok, contact} -> contact end)

            case process_avatar_for_contacts(
                   created_contacts,
                   scrapin_contact_details.photo_url
                 ) do
              {:ok, contacts_with_avatars} ->
                {:ok, contacts_with_avatars}

              {:error, reason} ->
                Logger.warning("Failed to process avatar for contacts", %{
                  linkedin_id: scrapin_contact_details.linked_in_identifier,
                  reason: reason
                })

                # Return contacts even if avatar processing failed
                {:ok, created_contacts}
            end
        end

      _ ->
        Logger.warning("No positions found in LinkedIn contact details")
        {:error, :no_positions_found}
    end
  end

  defp extract_common_fields(%ScrapinContactDetails{} = scrapin_contact_details) do
    %{
      first_name: scrapin_contact_details.first_name,
      last_name: scrapin_contact_details.last_name,
      full_name:
        build_full_name(
          scrapin_contact_details.first_name,
          scrapin_contact_details.last_name
        ),
      linkedin_id: scrapin_contact_details.linked_in_identifier,
      linkedin_alias: scrapin_contact_details.public_identifier,
      location: scrapin_contact_details.location,
      headline: scrapin_contact_details.headline,
      summary: scrapin_contact_details.summary
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

  defp create_or_update_contact_for_position(
         _common_fields,
         %ScrapinContactPosition{linked_in_id: nil}
       ) do
    Logger.warning("Skipping position without company linked_in_id")

    {:error, :missing_company_linked_in_id}
  end

  defp create_or_update_contact_for_position(
         common_fields,
         %ScrapinContactPosition{} = position
       ) do
    OpenTelemetry.Tracer.with_span "contacts.create_or_update_contact_for_position" do
      OpenTelemetry.Tracer.set_attributes([
        {"param.position.company_linkedin_id", position.linked_in_id}
      ])

      position_fields = extract_position_fields(position)
      contact_attrs = Map.merge(common_fields, position_fields)

      case find_existing_contact_by_linkedin_id_and_company_id(
             contact_attrs.linkedin_id,
             contact_attrs.linkedin_company_id
           ) do
        nil ->
          case create_contact(%Contact{}, contact_attrs) do
            {:ok, contact} ->
              {:ok, set_company_info_for_contact(contact)}

            {:error, reason} ->
              {:error, reason}
          end

        existing_contact ->
          if existing_contact.company_started_at == nil or
               (not is_nil(contact_attrs.company_started_at) and
                  DateTime.compare(
                    existing_contact.company_started_at,
                    contact_attrs.company_started_at
                  ) == :gt) do
            {:ok, _existing_contact} =
              update_contact_field(
                existing_contact.id,
                %{company_started_at: contact_attrs.company_started_at},
                "company started at"
              )
          end

          result =
            if should_update_contact(existing_contact, contact_attrs) do
              position_attrs = Map.delete(contact_attrs, :company_started_at)
              update_contact_with_position(existing_contact, position_attrs)
            else
              {:ok, existing_contact}
            end

          case result do
            {:ok, contact} ->
              {:ok, set_company_info_for_contact(contact)}

            {:error, reason} ->
              {:error, reason}
          end
      end
    end
  end

  defp create_or_update_contact_for_position(
         common_fields,
         %{} = position_map
       )
       when is_map(position_map) do
    position = StructUtils.safe_struct(position_map, ScrapinContactPosition)
    create_or_update_contact_for_position(common_fields, position)
  end

  defp extract_position_fields(position) do
    start_date = parse_start_date(position.start_end_date)

    %{
      job_title: position.title,
      linkedin_company_id: position.linked_in_id,
      job_description: position.description,
      job_started_at: start_date,
      job_ended_at: parse_end_date(position.start_end_date),
      # For new contacts, this will be updated if earlier positions are found
      company_started_at: start_date
    }
  end

  defp parse_start_date(start_end_date) when is_map(start_end_date) do
    case Map.get(start_end_date, :start) do
      nil -> nil
      date_map when is_map(date_map) -> parse_date_map(date_map)
      _ -> nil
    end
  end

  defp parse_start_date(_), do: nil

  defp parse_end_date(start_end_date) when is_map(start_end_date) do
    case Map.get(start_end_date, :end) do
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

  defp find_existing_contact_by_linkedin_id_and_company_id(
         linkedin_id,
         linkedin_company_id
       ) do
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
          # Keep existing if both have no start date
          {nil, nil} ->
            false

          # New wins if existing has no start date
          {nil, _} ->
            true

          # Existing wins if new has no start date
          {_, nil} ->
            false

          {existing, new} ->
            # Most recent start date wins
            DateTime.compare(new, existing) == :gt
        end

      # Default: keep existing
      true ->
        false
    end
  end

  defp update_contact_with_position(existing_contact, contact_attrs) do
    update_contact_field(
      existing_contact.id,
      contact_attrs,
      "position data"
    )
  end

  defp set_company_info_for_contact(contact) do
    if is_nil(contact.company_id) do
      set_company_info_if_needed(contact)
    else
      contact
    end
  end

  defp set_company_info_if_needed(contact) do
    case contact.linkedin_company_id do
      nil ->
        contact

      linkedin_company_id ->
        find_or_create_company_and_update_contact(contact, linkedin_company_id)
    end
  end

  defp find_or_create_company_and_update_contact(contact, linkedin_company_id) do
    OpenTelemetry.Tracer.with_span "contacts.find_or_create_company_and_update_contact" do
      OpenTelemetry.Tracer.set_attributes([
        {"param.contact.id", contact.id},
        {"param.linkedin_company_id", linkedin_company_id}
      ])

      case Companies.get_by_linkedin_id(linkedin_company_id) do
        {:ok, company} ->
          update_contact_company_info(contact, company)

        {:error, :not_found} ->
          create_company_and_update_contact(contact, linkedin_company_id)
      end
    end
  end

  defp create_company_and_update_contact(contact, linkedin_company_id) do
    OpenTelemetry.Tracer.with_span "contacts.create_company_and_update_contact" do
      OpenTelemetry.Tracer.set_attributes([
        {"param.contact.id", contact.id},
        {"param.linkedin_company_id", linkedin_company_id}
      ])

      case Companies.get_or_create_company_by_linkedin_id(linkedin_company_id) do
        {:ok, company} ->
          if linkedin_company_id in company.linkedin_ids do
            update_contact_company_info(contact, company)
          else
            Tracing.warning(
              :linkedin_id_mismatch,
              "Company created but LinkedIn ID not set, skipping contact association",
              contact_id: contact.id,
              linkedin_company_id: linkedin_company_id
            )

            contact
          end

        {:error, reason} ->
          Tracing.warning(
            reason,
            "Failed to create company for contact",
            contact_id: contact.id,
            linkedin_company_id: linkedin_company_id
          )

          contact
      end
    end
  end

  defp update_contact_company_info(contact, company) do
    case update_contact_field(
           contact.id,
           %{
             company_id: company.id,
             company_domain: company.primary_domain
           },
           "company information"
         ) do
      {:ok, updated_contact} ->
        updated_contact

      {:error, reason} ->
        Logger.warning("Failed to update contact with company info", %{
          contact_id: contact.id,
          company_id: company.id,
          reason: reason
        })

        contact
    end
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

  defp get_contact_by_id(contact_id) do
    case Repo.get(Contact, contact_id) do
      nil ->
        {:error, :contact_not_found}

      contact ->
        {:ok, contact}
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
      [] ->
        :not_found

      contacts ->
        {:ok, contacts}
    end
  end

  def get_target_persona_contacts_by_lead_id(tenant_id, lead_id) do
    OpenTelemetry.Tracer.with_span "contacts.get_target_persona_contacts_by_lead_id" do
      OpenTelemetry.Tracer.set_attributes([
        {"param.tenant.id", tenant_id},
        {"param.lead.id", lead_id}
      ])

      target_persona_contacts_query =
        from c in Contact,
          join: l in Core.Crm.Leads.Lead,
          on:
            l.ref_id == c.company_id and l.tenant_id == ^tenant_id and
              l.id == ^lead_id,
          join: tp in Core.Crm.TargetPersonas.TargetPersona,
          on: tp.contact_id == c.id and tp.tenant_id == ^tenant_id,
          join: comp in Core.Crm.Companies.Company,
          on: comp.id == c.company_id,
          select: {c, comp.name}

      contacts = Repo.all(target_persona_contacts_query)

      OpenTelemetry.Tracer.set_attributes([
        {"result.count", length(contacts)}
      ])

      Enum.map(contacts, fn {contact, company_name} ->
        time_current_position =
          CalculateTimeInPosition.calculate(
            contact.company_started_at,
            DateTime.utc_now()
          )

        {:ok, linkedin_url} = build_linkedin_url(contact)

        struct(ContactsView, %{
          id: contact.id,
          full_name: contact.full_name,
          job_title: contact.job_title,
          location: FormatLocation.format(contact.country_a2, contact.city),
          timezone: contact.timezone,
          current_time: format_current_time_in_timezone(contact.timezone),
          time_current_position: time_current_position,
          work_email: contact.business_email,
          phone_number: contact.mobile_phone,
          avatar_url: Images.get_cdn_url(contact.avatar_key),
          linkedin: linkedin_url,
          company_name: company_name
        })
      end)
    end
  end

  defp format_current_time_in_timezone(timezone)
       when is_binary(timezone) and timezone != "" do
    try do
      dt = Timex.now(timezone)
      Timex.format!(dt, "%H:%M", :strftime)
    rescue
      _ -> nil
    end
  end

  defp format_current_time_in_timezone(_) do
    nil
  end

  def update_business_email(business_email, status, contact_id) do
    OpenTelemetry.Tracer.with_span "contacts.update_business_email" do
      OpenTelemetry.Tracer.set_attributes([
        {"param.contact.id", contact_id},
        {"param.email", business_email},
        {"param.status", status}
      ])

      update_contact_field(
        contact_id,
        %{business_email: business_email, business_email_status: status},
        "business email"
      )
    end
  end

  def update_personal_email(personal_email, status, contact_id) do
    OpenTelemetry.Tracer.with_span "contacts.update_personal_email" do
      OpenTelemetry.Tracer.set_attributes([
        {"param.contact.id", contact_id},
        {"param.email", personal_email},
        {"param.status", status}
      ])

      update_contact_field(
        contact_id,
        %{personal_email: personal_email, personal_email_status: status},
        "personal email"
      )
    end
  end

  def update_mobile_phone(mobile_phone, contact_id) do
    OpenTelemetry.Tracer.with_span "contacts.update_mobile_phone" do
      OpenTelemetry.Tracer.set_attributes([
        {"param.contact.id", contact_id},
        {"param.mobile_phone", mobile_phone}
      ])

      update_contact_field(
        contact_id,
        %{mobile_phone: mobile_phone},
        "mobile phone"
      )
    end
  end

  @doc """
  Sets avatar for a single contact or list of contacts.

  For each contact:
  - If avatar_key is already present, skip
  - If another contact with same LinkedIn ID has avatar, reuse it
  - Otherwise, download and store new avatar from photo_url

  Returns {:ok, updated_contacts} or {:error, reason}
  """
  def set_avatar_for_contacts([%Contact{} | _] = contacts, photo_url) do
    process_avatar_for_contacts(contacts, photo_url)
  end

  def set_avatar_for_contacts(%Contact{} = contact, photo_url) do
    case process_avatar_for_contacts([contact], photo_url) do
      {:ok, [updated_contact]} ->
        {:ok, updated_contact}

      {:error, reason} ->
        {:error, reason}
    end
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
            Tracing.error(
              changeset.errors,
              "Failed to update contact #{field_name}",
              contact_id: contact_id
            )

            {:error, "Failed to update #{field_name}"}
        end
    end
  end

  defp process_avatar_for_contacts([%Contact{} | _] = contacts, photo_url) do
    case photo_url do
      nil ->
        {:ok, contacts}

      "" ->
        {:ok, contacts}

      photo_url ->
        # Process each contact individually
        results =
          Enum.map(contacts, fn contact ->
            process_avatar_for_contact(contact, photo_url)
          end)

        # Check if all processing was successful
        failed_results =
          Enum.filter(results, fn
            {:ok, _} -> false
            {:error, _} -> true
          end)

        case failed_results do
          [] ->
            # All successful, return updated contacts
            updated_contacts =
              Enum.map(results, fn {:ok, contact} -> contact end)

            {:ok, updated_contacts}

          _ ->
            Logger.error("Failed to process avatar for some contacts", %{
              failed_count: length(failed_results)
            })

            {:error, :avatar_processing_failed}
        end
    end
  end

  def process_avatar_for_contact(%Contact{} = contact, photo_url) do
    if is_nil(contact.avatar_key) do
      process_avatar_for_contact_without_avatar(contact, photo_url)
    else
      {:ok, contact}
    end
  end

  defp process_avatar_for_contact_without_avatar(contact, photo_url) do
    case find_existing_avatar_key_by_linkedin_id(contact.linkedin_id) do
      {:ok, existing_avatar_key} ->
        update_contact_with_avatar_key(contact, existing_avatar_key, "existing")

      {:error, :not_found} ->
        download_avatar_and_update_contact(contact, photo_url)
    end
  end

  defp download_avatar_and_update_contact(contact, photo_url) do
    case download_and_store_avatar(photo_url) do
      {:ok, avatar_key} ->
        update_contact_with_avatar_key(contact, avatar_key, "new")

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp update_contact_with_avatar_key(contact, avatar_key, key_type) do
    case update_contact_field(
           contact.id,
           %{avatar_key: avatar_key},
           "avatar_key"
         ) do
      {:ok, updated_contact} ->
        {:ok, updated_contact}

      {:error, reason} ->
        Logger.error(
          "Failed to update contact with #{key_type} avatar key",
          %{
            contact_id: contact.id,
            reason: reason
          }
        )

        {:error, reason}
    end
  end

  defp find_existing_avatar_key_by_linkedin_id(linkedin_id)
       when is_nil(linkedin_id) or linkedin_id == "" do
    {:error, :not_found}
  end

  defp find_existing_avatar_key_by_linkedin_id(linkedin_id) do
    case Repo.all(
           from c in Contact,
             where: c.linkedin_id == ^linkedin_id and not is_nil(c.avatar_key),
             limit: 1
         ) do
      [] -> {:error, :not_found}
      [contact | _] -> {:ok, contact.avatar_key}
    end
  end

  def download_and_store_avatar(photo_url) do
    OpenTelemetry.Tracer.with_span "contacts.download_and_store_avatar" do
      OpenTelemetry.Tracer.set_attributes([
        {"param.photo_url", photo_url}
      ])

      case download_linkedin_avatar_with_fallback(photo_url) do
        {:ok, image_data} ->
          case Images.store_image(
                 image_data,
                 "image/jpeg",
                 photo_url,
                 %{generate_name: true, path: "_contacts"}
               ) do
            {:ok, storage_key} ->
              {:ok, storage_key}

            {:error, reason} ->
              Tracing.error(
                reason,
                "Failed to store avatar image: #{photo_url}"
              )

              {:error, reason}
          end

        {:error, reason} ->
          Tracing.error(reason, "Failed to download avatar image: #{photo_url}")

          {:error, reason}
      end
    end
  end

  defp download_linkedin_avatar_with_fallback(photo_url) do
    # Try multiple strategies for LinkedIn URLs
    strategies = [
      # Strategy 1: HTTPoison with standard headers and LinkedIn referer
      fn ->
        headers = [
          {"User-Agent",
           "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"},
          {"Accept",
           "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8"},
          {"Accept-Language", "en-US,en;q=0.9"},
          {"Referer", "https://www.linkedin.com/"}
        ]

        Images.download_image_with_httpoison(photo_url, headers)
      end,

      # Strategy 2: HTTPoison with standard headers without referer
      fn ->
        headers = [
          {"User-Agent",
           "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"},
          {"Accept",
           "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8"},
          {"Accept-Language", "en-US,en;q=0.9"}
        ]

        Images.download_image_with_httpoison(photo_url, headers)
      end,

      # Strategy 6: HTTPoison with different User-Agent
      fn ->
        headers = [
          {"User-Agent",
           "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"},
          {"Accept",
           "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8"},
          {"Accept-Language", "en-US,en;q=0.9"},
          {"Referer", "https://www.linkedin.com/"}
        ]

        Images.download_image_with_httpoison(photo_url, headers)
      end
    ]

    try_strategies(strategies, photo_url)
  end

  defp try_strategies(strategies, photo_url, attempt \\ 1) do
    case strategies do
      [strategy | remaining_strategies] ->
        case strategy.() do
          {:ok, image_data} ->
            Logger.debug(
              "LinkedIn avatar download succeeded with strategy #{attempt}",
              %{
                photo_url: photo_url
              }
            )

            {:ok, image_data}

          {:error, reason} ->
            Logger.debug(
              "LinkedIn avatar download failed with strategy #{attempt}",
              %{
                photo_url: photo_url,
                reason: reason,
                strategy: attempt
              }
            )

            # Add a small delay between attempts
            Process.sleep(500)
            try_strategies(remaining_strategies, photo_url, attempt + 1)
        end

      [] ->
        Logger.error(
          "All LinkedIn avatar download strategies failed: #{photo_url}"
        )

        {:error, :download_failed}
    end
  end

  @doc """
  Starts email enrichment for a contact.

  Only enriches if:
  - Contact is active (no end date or end date is in the future)
  - Contact has a company
  - Email enrichment hasn't been requested recently
  """
  def start_email_enrichment(contact_id) do
    case get_contact_by_id(contact_id) do
      {:ok, contact} ->
        case validate_email_enrichment_eligibility(contact) do
          :ok ->
            case get_company_domain(contact.company_id) do
              {:ok, company_domain} ->
                start_better_contact_enrichment(contact, company_domain, :email)

              {:error, reason} ->
                Logger.warning(
                  "Failed to get company domain for email enrichment",
                  %{
                    contact_id: contact_id,
                    company_id: contact.company_id,
                    reason: reason
                  }
                )

                {:error, reason}
            end

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  def start_email_and_phone_enrichment(contact_id) do
    case get_contact_by_id(contact_id) do
      {:ok, contact} ->
        case validate_phone_enrichment_eligibility(contact) do
          :ok ->
            case get_company_domain(contact.company_id) do
              {:ok, company_domain} ->
                start_better_contact_enrichment(
                  contact,
                  company_domain,
                  :email_and_phone
                )

              {:error, reason} ->
                Logger.warning("Failed to get company domain for enrichment", %{
                  contact_id: contact_id,
                  company_id: contact.company_id,
                  reason: reason
                })

                {:error, reason}
            end

          {:error, reason} ->
            {:error, reason}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp validate_email_enrichment_eligibility(%Contact{} = contact) do
    cond do
      not active_contact?(contact) ->
        {:error, :contact_not_active}

      is_nil(contact.company_id) ->
        {:error, :no_company}

      is_nil(contact.first_name) or contact.first_name == "" ->
        {:error, :missing_first_name}

      is_nil(contact.last_name) or contact.last_name == "" ->
        {:error, :missing_last_name}

      not is_nil(contact.business_email) and contact.business_email != "" ->
        {:error, :business_email_already_set}

      email_enrichment_recently_requested?(contact) ->
        {:error, :email_enrichment_recently_requested}

      true ->
        :ok
    end
  end

  defp validate_phone_enrichment_eligibility(%Contact{} = contact) do
    cond do
      not active_contact?(contact) ->
        {:error, :contact_not_active}

      is_nil(contact.company_id) ->
        {:error, :no_company}

      is_nil(contact.first_name) or contact.first_name == "" ->
        {:error, :missing_first_name}

      is_nil(contact.last_name) or contact.last_name == "" ->
        {:error, :missing_last_name}

      email_enrichment_recently_requested?(contact) or
          phone_enrichment_recently_requested?(contact) ->
        {:error, :enrichment_recently_requested}

      true ->
        :ok
    end
  end

  defp active_contact?(contact) do
    is_nil(contact.job_ended_at) or
      DateTime.compare(contact.job_ended_at, DateTime.utc_now()) == :gt
  end

  defp email_enrichment_recently_requested?(contact) do
    case contact.email_enrich_requested_at do
      nil ->
        false

      requested_at ->
        DateTime.diff(DateTime.utc_now(), requested_at, :hour) < 48
    end
  end

  defp phone_enrichment_recently_requested?(contact) do
    case contact.phone_enrich_requested_at do
      nil ->
        false

      requested_at ->
        DateTime.diff(DateTime.utc_now(), requested_at, :hour) < 48
    end
  end

  defp get_company_domain(company_id) do
    case Companies.get_by_id(company_id) do
      {:ok, company} ->
        {:ok, company.primary_domain}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp start_better_contact_enrichment(contact, company_domain, search_type) do
    linkedin_url =
      case build_linkedin_url(contact) do
        {:ok, url} -> url
      end

    request =
      BetterContactRequest.new(
        contact.first_name,
        contact.last_name,
        search_type,
        # We'll use domain instead
        company_name: nil,
        company_domain: company_domain,
        linkedin_url: linkedin_url,
        contact_id: contact.id
      )

    case request do
      %BetterContactRequest{} = valid_request ->
        case BetterContact.start_search(valid_request) do
          {:ok, _job_record} ->
            case mark_enrichment_requested(contact.id, search_type) do
              {:ok, _} ->
                {:ok, :enrichment_started}

              {:error, reason} ->
                Logger.error("Failed to mark enrichment as requested", %{
                  contact_id: contact.id,
                  search_type: search_type,
                  reason: reason
                })

                {:error, reason}
            end

          {:error, reason} ->
            Logger.error("Failed to start BetterContact enrichment", %{
              contact_id: contact.id,
              search_type: search_type,
              reason: reason
            })

            {:error, reason}
        end

      {:error, reason} ->
        Logger.error("Invalid BetterContact request", %{
          contact_id: contact.id,
          reason: reason
        })

        {:error, reason}
    end
  end

  defp mark_enrichment_requested(contact_id, search_type) do
    now = DateTime.utc_now()

    attrs =
      case search_type do
        :email ->
          %{email_enrich_requested_at: now}

        :phone ->
          %{phone_enrich_requested_at: now}

        :email_and_phone ->
          %{
            email_enrich_requested_at: now,
            phone_enrich_requested_at: now
          }
      end

    update_contact_field(contact_id, attrs, "enrichment request tracking")
  end

  defp build_linkedin_url(contact) do
    case {contact.linkedin_id, contact.linkedin_alias} do
      {_, linkedin_alias}
      when not is_nil(linkedin_alias) and linkedin_alias != "" ->
        {:ok, "#{@linkedin_url_prefix}#{linkedin_alias}"}

      {linkedin_id, _} when not is_nil(linkedin_id) and linkedin_id != "" ->
        {:ok, "#{@linkedin_url_prefix}#{linkedin_id}"}

      _ ->
        {:ok, nil}
    end
  end
end
