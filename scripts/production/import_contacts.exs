Application.ensure_all_started(:core)

@wait_ms 500

defmodule ContactImporter do

  def build_request(row) do


    %Core.Crm.Contacts.Contact{
      first_name: row["first_name"],
      last_name: row["last_name"],
      full_name: row["first_name"] <> " " <> row["last_name"],
      linkedin_id: row["linked_in_identifier"],
      linkedin_alias: row["linked_in_alias"],
      business_email: row["work_email"],
      personal_email: row["personal_email"],
      mobile_phone: row["phone_number"],
      avatar_key: row["profile_photo_path"],
      current_job_title: row["job_title"]
    }
  end

  def parse_location(loc_string) do
  end

  def run(path, limit \\ nil) do
    stream = path
      |> File.stream!()
      |> CSV.decode(headers: true)
      |> Stream.filter(&match?({:ok, _}, &1))
      |> Stream.map(&elem(&1, 1))

    stream = if limit, do: Stream.take(stream, limit), else: stream
    
    stream
    |> Stream.map(&build_request(&1))
    |> Stream.with_index(1)  
    |> Stream.each(fn {contact, index} ->
      Core.Crm.Contacts.Contact.create_contact(contact)
      IO.puts("Processing record #{index}")
      Process.sleep(@wait_ms)
    end)
    |> Stream.run()  

  end
  
end
