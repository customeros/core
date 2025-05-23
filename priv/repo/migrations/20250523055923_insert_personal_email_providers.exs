defmodule Core.Repo.Migrations.InsertPersonalEmailProviders do
  use Ecto.Migration

  def up do
    csv_path = Path.join([File.cwd!(), "priv", "personal_email_providers.csv"])

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
        raise "Error reading personal_email_providers.csv: #{reason}"
    end
  end

  def down do
    csv_path = Path.join([File.cwd!(), "priv", "personal_email_providers.csv"])

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
        raise "Error reading personal_email_providers.csv in down(): #{reason}"
    end
  end
end
