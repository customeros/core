defmodule Web.ContactsController do
  use Web, :controller

  def index(conn, params) do
    case params do
      %{} ->
        handle_all_contacts(conn)

      _ ->
        handle_search(conn, params)
    end

    # search for first name, last name, current company, current title, linkedin url, location, email, phone
  end

  defp handle_search(conn, %{"linkedinUrl" => linkedin_url}) do
    search_by_linkedin(conn, linkedin_url)
  end

  defp handle_search(_conn, _params) do
  end

  defp search_by_linkedin(conn, linkedin_url) do
    # check if we have in db
    # if not, call scrapin
    # call better contact
  end

  defp handle_all_contacts(conn) do
    conn
    |> put_status(:ok)
    |> json(%{status: "ok"})
  end
end
