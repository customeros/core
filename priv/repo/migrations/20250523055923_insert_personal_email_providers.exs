defmodule Core.Repo.Migrations.InsertPersonalEmailProviders do
  use Ecto.Migration
  require Logger

  def up do
    csv_path = Path.join([:code.priv_dir(:core), "personal_email_providers.csv"])

    case File.read(csv_path) do
      {:ok, content} ->
        content
        |> String.split("\n", trim: true)
        |> Enum.each(fn domain ->
          domain = domain |> String.trim() |> String.downcase()

          execute("""
          INSERT INTO personal_email_providers (domain)
          VALUES ('#{domain}')
          ON CONFLICT (domain) DO NOTHING;
          """)
        end)

      {:error, reason} ->
        Logger.warning("Could not read personal_email_providers.csv: #{reason}. Skipping data insertion.")
    end
  end

  def down do
    csv_path = Path.join([:code.priv_dir(:core), "personal_email_providers.csv"])

    case File.read(csv_path) do
      {:ok, content} ->
        content
        |> String.split("\n", trim: true)
        |> Enum.each(fn domain ->
          domain = domain |> String.trim() |> String.downcase()

          execute("""
          DELETE FROM personal_email_providers WHERE domain = '#{domain}';
          """)
        end)

      {:error, reason} ->
        Logger.warning("Could not read personal_email_providers.csv in down(): #{reason}. Skipping data deletion.")
    end
  end
end
