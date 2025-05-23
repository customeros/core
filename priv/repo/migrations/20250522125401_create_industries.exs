defmodule Core.Repo.Migrations.CreateIndustries do
  use Ecto.Migration

  defp parse_csv_line(line) do
    case Regex.run(~r/^([^,]+),"([^"]*)"$/, line) do
      [_, code, name] ->
        {code, name}

      _ ->
        [code, name] = String.split(line, ",", parts: 2)
        {code, name}
    end
  end

  def up do
    create table(:industries, primary_key: false) do
      add(:code, :string, primary_key: true)
      add(:name, :string, null: false)

      timestamps(type: :utc_datetime)
    end

    csv_path = Path.join([File.cwd!(), "priv", "industries.csv"])

    case File.read(csv_path) do
      {:ok, content} ->
        content
        |> String.split("\n", trim: true)
        |> Enum.each(fn line ->
          {code, name} = parse_csv_line(line)

          execute("""
          INSERT INTO industries (code, name, inserted_at, updated_at)
          VALUES ('#{code}', '#{name}', NOW(), NOW())
          ON CONFLICT (code) DO NOTHING;
          """)
        end)

      {:error, reason} ->
        raise "Error reading industries.csv during migration: #{reason}"
    end
  end

  def down do
    drop table(:industries)
  end
end
