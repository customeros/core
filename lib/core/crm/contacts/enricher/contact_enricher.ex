defmodule Core.Crm.Contacts.Enricher.ContactEnricher do
  @moduledoc """
  GenServer responsible for periodically enriching contact location data.
  Runs every 2 or 15 minutes (based on found records) and processes contacts that need location enrichment.
  """
  use GenServer
  require Logger
  require OpenTelemetry.Tracer
  import Ecto.Query

  alias Core.Repo
  alias Core.Crm.Contacts.Contact
  alias Core.Crm.Contacts.Enricher.LocationAI
  alias Core.Crm.Contacts.Enricher.LocationMapping
  alias Core.Utils.Tracing
  alias Core.Utils.CronLocks
  alias Core.Utils.Cron.CronLock

  @cron_name :cron_contact_enricher
  @default_interval_ms 2 * 60 * 1000
  @long_interval_ms 10 * 60 * 1000
  @default_batch_size 10
  @stuck_lock_duration_minutes 30
  @max_attempts 5
  @delay_between_checks_hours 48
  @delay_from_contact_creation_minutes 10

  def start_link(opts \\ []) do
    crons_enabled = Application.get_env(:core, :crons)[:enabled] || false

    if crons_enabled do
      GenServer.start_link(__MODULE__, opts, name: __MODULE__)
    else
      Logger.info("Contact enricher is disabled (crons disabled)")
      :ignore
    end
  end

  @impl true
  def init(_opts) do
    CronLocks.register_cron(@cron_name)

    # Schedule the first check
    schedule_check(@default_interval_ms)

    {:ok, %{}}
  end

  @impl true
  def handle_info(:enrich_contacts, state) do
    OpenTelemetry.Tracer.with_span "contact_enricher.enrich_contacts" do
      lock_uuid = Ecto.UUID.generate()

      case CronLocks.acquire_lock(@cron_name, lock_uuid) do
        %CronLock{} ->
          {_, num_contacts_enriched} = enrich_contacts()

          CronLocks.release_lock(@cron_name, lock_uuid)

          # Schedule the next check based on whether we hit the batch size
          next_interval_ms =
            if num_contacts_enriched == @default_batch_size do
              @default_interval_ms
            else
              @long_interval_ms
            end

          schedule_check(next_interval_ms)

        nil ->
          # Lock not acquired, try to force release if stuck
          Logger.info(
            "Contact enricher lock not acquired, attempting to release any stuck locks"
          )

          case CronLocks.force_release_stuck_lock(
                 @cron_name,
                 @stuck_lock_duration_minutes
               ) do
            :ok ->
              Logger.info(
                "Successfully released stuck lock, will retry acquisition on next run"
              )

            :error ->
              Logger.info("No stuck lock found or could not release it")
          end

          schedule_check(@default_interval_ms)
      end

      {:noreply, state}
    end
  end

  @impl true
  def handle_info(msg, state) do
    Logger.warning(
      "ContactEnricher received unexpected message: #{inspect(msg)}"
    )

    {:noreply, state}
  end

  # Schedule the next check
  defp schedule_check(interval_ms) do
    Process.send_after(self(), :enrich_contacts, interval_ms)
  end

  defp enrich_contacts() do
    OpenTelemetry.Tracer.with_span "contact_enricher.enrich_contacts_batch" do
      contacts = fetch_contacts_for_enrichment(@default_batch_size)

      OpenTelemetry.Tracer.set_attributes([
        {"param.contacts.found", length(contacts)},
        {"param.batch.size", @default_batch_size}
      ])

      Enum.each(contacts, fn contact ->
        contact
        |> increment_attempt()
        |> enrich_contact_location()
        |> enrich_contact_avatar()
      end)

      Enum.each(contacts, &enrich_contact_avatar/1)
      {:ok, length(contacts)}
    end
  end

  defp fetch_contacts_for_enrichment(batch_size) do
    last_check_cutoff =
      DateTime.utc_now()
      |> DateTime.add(-@delay_between_checks_hours, :hour)

    contact_created_cutoff =
      DateTime.utc_now()
      |> DateTime.add(-@delay_from_contact_creation_minutes, :minute)

    Contact
    |> where(
      [c],
      (not is_nil(c.location) and c.location != "" and
         (is_nil(c.country_a2) or c.country_a2 == "") and
         (is_nil(c.city) or c.city == "") and
         (is_nil(c.region) or c.region == "")) or
        is_nil(c.avatar_key)
    )
    |> where([c], c.enrich_attempts < @max_attempts)
    |> where(
      [c],
      is_nil(c.enrich_attempt_at) or
        c.enrich_attempt_at < ^last_check_cutoff
    )
    |> where([c], c.inserted_at < ^contact_created_cutoff)
    |> order_by([c], asc_nulls_first: c.enrich_attempt_at)
    |> limit(^batch_size)
    |> Repo.all()
  end

  defp enrich_contact_location(%{location: nil} = contact),
    do: contact

  defp enrich_contact_location(%{location: ""} = contact),
    do: contact

  defp enrich_contact_location(
         %{
           location: location,
           country_a2: country,
           city: city,
           region: region
         } = contact
       )
       when is_binary(location) and
              is_binary(country) and country != "" and
              is_binary(city) and city != "" and
              is_binary(region) and region != "",
       do: contact

  defp enrich_contact_location(%{location: location} = contact)
       when is_binary(location) do
    OpenTelemetry.Tracer.with_span "contact_enricher.enrich_location" do
      OpenTelemetry.Tracer.set_attributes([
        {"contact.id", contact.id},
        {"contact.location", contact.location}
      ])

      {:ok, contact} = increment_attempt(contact)

      case Repo.get_by(LocationMapping, location: contact.location) do
        %LocationMapping{} = mapping ->
          update_contact_with_mapping(contact, mapping)

        nil ->
          case LocationAI.parse_location(contact.location) do
            {:ok, location_data} ->
              {:ok, mapping} =
                %LocationMapping{}
                |> LocationMapping.changeset(
                  Map.put(location_data, "location", contact.location)
                )
                |> Repo.insert()

              update_contact_with_mapping(contact, mapping)

            {:error, reason} ->
              Tracing.error(reason, "Failed to parse location")
              {:error, reason}
          end
      end
    end
  end

  defp enrich_contact_avatar(%{avatar_key: avatar_key} = contact)
       when is_nil(avatar_key) and is_binary(contact.linkedin_id) do
    OpenTelemetry.Tracer.with_span "contact_enricher.enrich_avatar" do
      OpenTelemetry.Tracer.set_attributes([
        {"contact.id", contact.id},
        {"contact.avatar_key", avatar_key}
      ])

      case Core.ScrapinContacts.get_scrapin_contact_record_by_linkedin_id(
             contact.linkedin_id
           ) do
        {:ok, record} ->
          case Core.ScrapinContacts.parse_contact_from_record(record) do
            {:ok, details} ->
              case details do
                %{photo_url: photo_url} ->
                  Core.Crm.Contacts.process_avatar_for_contact(
                    contact,
                    photo_url
                  )

                _ ->
                  contact
              end
          end

        _ ->
          contact
      end
    end
  end

  defp increment_attempt(contact) do
    OpenTelemetry.Tracer.with_span "contact_enricher.increment_attempt" do
      case contact
           |> Contact.changeset(%{
             enrich_attempts: contact.enrich_attempts + 1,
             enrich_attempt_at: DateTime.utc_now()
           })
           |> Repo.update() do
        {:ok, updated_contact} = result ->
          updated_contact

        {:error, reason} = error ->
          Tracing.error(reason, "Failed to increment attempt",
            contact_id: contact.id
          )

          contact
      end
    end
  end

  defp update_contact_with_mapping(contact, mapping) do
    # Get values directly from the struct fields
    attrs = %{
      country_a2: mapping.country_a2,
      region: mapping.region,
      city: mapping.city,
      timezone: mapping.timezone
    }

    case contact
         |> Contact.changeset(attrs)
         |> Repo.update() do
      {:ok, _updated_contact} = result ->
        Tracing.ok()
        result

      {:error, reason} = error ->
        Tracing.error(reason, "Failed to update contact with location data",
          contact_id: contact.id
        )

        error
    end
  end
end
