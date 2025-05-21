defmodule Core.Repo.Migrations.CreateApiCallLogs do
  use Ecto.Migration

  def change do
    create table(:api_call_logs, primary_key: false) do
      add :id, :string, primary_key: true
      add :vendor, :string, null: false
      add :method, :string, null: false
      add :url, :string, null: false
      add :request_body, :binary
      add :duration, :integer, null: false
      add :status_code, :integer
      add :response_body, :binary
      add :error_message, :text

      timestamps(type: :utc_datetime)
    end

    # Create indexes for common queries
    create index(:api_call_logs, [:vendor])
    create index(:api_call_logs, [:inserted_at])
    create index(:api_call_logs, [:vendor, :inserted_at])
  end
end
