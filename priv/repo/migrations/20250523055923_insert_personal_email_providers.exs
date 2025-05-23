defmodule Core.Repo.Migrations.InsertPersonalEmailProviders do
  use Ecto.Migration

  def change do
    # Import data from CSV
    csv_path = Path.join([File.cwd!(), "priv", "personal_email_providers.csv"])

    case File.read(csv_path) do
      {:ok, content} ->
        content
        |> String.split("\n", trim: true)
        |> Enum.each(fn domain ->
          domain = String.trim(domain) |> String.downcase()
          execute """
          INSERT INTO personal_email_providers (domain)
          VALUES ('#{domain}')
          ON CONFLICT (domain) DO NOTHING;
          """
        end)

      {:error, reason} ->
        IO.puts("Error reading CSV file: #{reason}")
    end
  end
end
