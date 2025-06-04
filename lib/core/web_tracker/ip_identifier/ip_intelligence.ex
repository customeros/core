defmodule Core.WebTracker.IpIdentifier.IpIntelligence do
  @moduledoc """
  Schema for IP intelligence records.
  """

  require Logger

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Core.Repo

  @primary_key {:id, :string, autogenerate: false}
  @id_prefix "ip"
  @id_regex ~r/^ip_[a-z0-9]{21}$/

  schema "ip_intelligence" do
    field(:ip, :string)
    field(:domain_source, Ecto.Enum, values: [:snitcher])
    field(:domain, :string)
    field(:is_mobile, :boolean)
    field(:city, :string)
    field(:region, :string)
    field(:country, :string)
    field(:has_threat, :boolean)
    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{
          id: String.t(),
          ip: String.t(),
          domain_source: String.t() | nil,
          domain: String.t() | nil,
          is_mobile: boolean() | nil,
          city: String.t() | nil,
          region: String.t() | nil,
          country: String.t() | nil,
          has_threat: boolean() | nil,
          inserted_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @doc """
  Returns the ID prefix used for ip_intelligence records.
  """
  def id_prefix, do: @id_prefix

  @doc """
  Changeset for ip_intelligence.
  """
  def changeset(ip_intelligence, attrs) do
    ip_intelligence
    |> cast(attrs, [
      :id,
      :ip,
      :domain_source,
      :domain,
      :is_mobile,
      :has_threat,
      :city,
      :region,
      :country
    ])
    |> validate_required([:id, :ip])
    |> validate_format(:id, @id_regex)
  end

  @doc """
  Finds the most recent IP intelligence record for a given IP address within a lookback window.

  ## Parameters
    - ip: The IP address to search for (string)
    - lookback_days: Number of days to look back (default: 90)

  ## Returns
    - {:ok, record} if a record is found
    - {:ok, nil} if no record is found within the lookback window
    - {:error, reason} if there's an error during the query
  """
  @spec get_by_ip(String.t(), non_neg_integer()) ::
          {:ok, t() | nil} | {:error, term()}
  def get_by_ip(ip, lookback_days \\ 90)

  def get_by_ip(ip, lookback_days)
      when is_binary(ip) and is_integer(lookback_days) and lookback_days >= 0 do
    cutoff_date =
      DateTime.utc_now() |> DateTime.add(-lookback_days * 24 * 60 * 60, :second)

    query =
      from i in __MODULE__,
        where: i.ip == ^ip and i.inserted_at >= ^cutoff_date,
        order_by: [desc: i.inserted_at],
        limit: 1

    case Repo.one(query) do
      nil -> {:ok, nil}
      record -> {:ok, record}
    end
  rescue
    e in Ecto.QueryError ->
      Logger.error("Failed to query IP intelligence: #{inspect(e)}")
      {:error, :query_error}

    e in ArgumentError ->
      Logger.error("Invalid argument in IP intelligence query: #{inspect(e)}")
      {:error, :invalid_argument}
  end

  def get_by_ip(_, _), do: {:error, :invalid_arguments}

  @doc """
  Gets the domain associated with an IP address from the most recent IP intelligence record.

  ## Parameters
    - ip: The IP address to search for (string)
    - lookback_days: Number of days to look back (default: 90)

  ## Returns
    - {:ok, domain} if a record is found and has a non-empty domain
    - {:error, :not_found} if no record exists or the record has no domain
    - {:error, reason} if there's an error during the query
  """
  @spec get_domain_by_ip(String.t(), non_neg_integer()) ::
          {:ok, String.t()} | {:error, :not_found | term()}
  def get_domain_by_ip(ip, lookback_days \\ 90)

  def get_domain_by_ip(ip, lookback_days) when is_binary(ip) do
    case get_by_ip(ip, lookback_days) do
      {:ok, %__MODULE__{domain: domain}}
      when is_binary(domain) and domain != "" ->
        {:ok, domain}

      {:ok, _} ->
        {:error, :not_found}

      {:error, reason} ->
        Logger.error("Failed to get domain by IP: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def get_domain_by_ip(_, _), do: {:error, :invalid_arguments}
end
