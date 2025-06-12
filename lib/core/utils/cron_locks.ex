defmodule Core.Utils.CronLocks do
  @moduledoc """
  Functions for managing cron job locks.

  This module provides operations for registering and managing cron job locks,
  ensuring that only one instance of each cron job can run at a time.
  """

  require Logger
  alias Core.Repo
  alias Core.Utils.Cron.CronLock
  import Ecto.Query

  @valid_cron_names CronLock.valid_cron_names()

  @err_invalid_cron_name {:error, "invalid cron name"}

  @doc """
  Registers a cron job in the locking system if it doesn't exist.

  This function is idempotent; it will not fail if the cron job is already registered.
  It should be called during application startup to ensure all cron jobs are registered.
  """
  @spec register_cron(CronLock.cron_name()) ::
          :ok | {:error, :invalid_cron_name}
  def register_cron(cron_name) when cron_name in @valid_cron_names do
    case Repo.insert(
           %CronLock{cron_name: cron_name},
           on_conflict: :nothing,
           conflict_target: :cron_name
         ) do
      {:ok, _cron_lock} ->
        :ok

      {:error, _changeset} ->
        Logger.error("Failed to register cron job: #{cron_name}")
        :ok
    end
  end

  def register_cron(invalid_name) do
    Logger.error(
      "Attempted to register invalid cron name: #{inspect(invalid_name)}"
    )

    @err_invalid_cron_name
  end

  @doc """
  Attempts to acquire a lock for a cron job.

  The lock will only be acquired if the cron job is not currently locked.
  Returns the updated cron lock record if the lock was acquired, nil otherwise.

  ## Examples

      iex> acquire_lock(:cron_company_enricher, "123e4567-e89b-12d3-a456-426614174000")
      %CronLock{...}  # Lock acquired
      nil  # Lock not acquired
  """
  @spec acquire_lock(CronLock.cron_name(), String.t()) :: CronLock.t() | nil
  def acquire_lock(cron_name, lock_uuid) when cron_name in @valid_cron_names do
    # First try to find and update the record in a single query
    # This ensures atomicity of the lock acquisition
    query =
      from c in CronLock,
        where: c.cron_name == ^cron_name,
        where: is_nil(c.lock) or c.lock == "",
        update: [set: [lock: ^lock_uuid, locked_at: ^DateTime.utc_now()]],
        select: c

    case Repo.update_all(query, []) do
      {1, [cron_lock]} ->
        # Lock was acquired
        cron_lock

      {0, []} ->
        # No lock was acquired (either record doesn't exist or is already locked)
        nil
    end
  end

  def acquire_lock(invalid_name, _lock_uuid) do
    Logger.error(
      "Attempted to acquire lock for invalid cron name: #{inspect(invalid_name)}"
    )

    nil
  end

  @doc """
  Attempts to release a lock for a cron job and update the last execution time.

  The lock will only be released if the provided UUID matches the current lock.
  This ensures that only the process that acquired the lock can release it.
  The last_execution_at field will be updated to the current time.

  ## Examples

      iex> release_lock(:cron_company_enricher, "123e4567-e89b-12d3-a456-426614174000")
      :ok  # Lock released and last execution time updated
      :error  # Lock not released (UUID mismatch or no lock)
  """
  @spec release_lock(CronLock.cron_name(), String.t()) :: :ok | :error
  def release_lock(cron_name, lock_uuid) when cron_name in @valid_cron_names do
    now = DateTime.utc_now()

    # Only release if the UUID matches and update last_execution_at
    query =
      from c in CronLock,
        where: c.cron_name == ^cron_name,
        where: c.lock == ^lock_uuid,
        update: [set: [lock: nil, locked_at: nil, last_execution_at: ^now]]

    case Repo.update_all(query, []) do
      {1, _} -> :ok
      {0, _} -> :error
    end
  end

  def release_lock(invalid_name, _lock_uuid) do
    Logger.error(
      "Attempted to release lock for invalid cron name: #{inspect(invalid_name)}"
    )

    :error
  end

  @doc """
  Gets the last execution time for a cron job.

  Returns the last_execution_at timestamp if available, nil otherwise.

  ## Examples

      iex> get_last_execution_time(:cron_company_enricher)
      ~U[2024-03-14 06:00:00Z]  # Last execution time
      nil  # No previous execution
  """
  @spec get_last_execution_time(CronLock.cron_name()) :: DateTime.t() | nil
  def get_last_execution_time(cron_name) when cron_name in @valid_cron_names do
    query =
      from c in CronLock,
        where: c.cron_name == ^cron_name,
        select: c.last_execution_at

    case Repo.one(query) do
      nil -> nil
      timestamp -> timestamp
    end
  end

  def get_last_execution_time(invalid_name) do
    Logger.error(
      "Attempted to get last execution time for invalid cron name: #{inspect(invalid_name)}"
    )

    nil
  end

  @doc """
  Forcefully releases a stuck cron job lock if it's older than the specified duration.

  ## Examples

      iex> force_release_stuck_lock(:cron_company_enricher, 30)
      :ok  # Lock released if it was older than 30 minutes
      :error  # No stuck lock found or lock was too recent
  """
  @spec force_release_stuck_lock(CronLock.cron_name(), pos_integer()) ::
          :ok | :error
  def force_release_stuck_lock(cron_name, max_duration_minutes)
      when cron_name in @valid_cron_names and max_duration_minutes > 0 do
    cutoff_time = DateTime.add(DateTime.utc_now(), -max_duration_minutes * 60)

    query =
      from c in CronLock,
        where: c.cron_name == ^cron_name,
        where: not is_nil(c.lock),
        where: c.locked_at < ^cutoff_time,
        update: [set: [lock: nil, locked_at: nil]]

    case Repo.update_all(query, []) do
      {1, _} ->
        Logger.info(
          "Force released stuck lock for cron job: #{cron_name} (older than #{max_duration_minutes} minutes)"
        )

        :ok

      {0, _} ->
        Logger.info(
          "No stuck lock found for cron job: #{cron_name} (older than #{max_duration_minutes} minutes)"
        )

        :error
    end
  end

  def force_release_stuck_lock(invalid_name, _max_duration_minutes) do
    Logger.error(
      "Attempted to force release stuck lock for invalid cron name: #{inspect(invalid_name)}"
    )

    :error
  end
end
