defmodule Web.Controllers.Integrations.HubspotController do
  @moduledoc """
  Controller for handling HubSpot integration operations.

  This controller manages the OAuth flow and integration management for HubSpot,
  including authorization, callback handling, and disconnection.
  """

  use Web, :controller
  require Logger

  alias Core.Integrations.Connections
  alias Core.Integrations.Registry
  alias Core.Integrations.OAuth.Providers.HubSpot, as: HubSpotOAuth

  @doc """
  Initiates the HubSpot OAuth authorization flow.

  Returns an error if a connection already exists for the tenant.
  """
  def connect(conn, _params) do
    tenant_id = conn.assigns.current_user.tenant_id

    config = Application.get_env(:core, :hubspot)
    redirect_uri = config[:redirect_uri]

    # Check for existing connection
    case Registry.get_connection(tenant_id, :hubspot) do
      {:ok, _connection} ->
        conn
        |> put_status(:conflict)
        |> json(%{
          status: "error",
          message:
            "A HubSpot connection already exists. Please disconnect it first before creating a new one."
        })

      {:error, :not_found} ->
        case HubSpotOAuth.authorize_url(tenant_id, redirect_uri) do
          {:ok, url} ->
            conn
            |> put_status(302)
            |> put_resp_header("location", url)
            |> send_resp(302, "")
        end
    end
  end

  @doc """
  Handles the OAuth callback from HubSpot.
  """
  def callback(conn, params) do
    tenant_id = conn.assigns.current_user.tenant_id

    config = Application.get_env(:core, :hubspot)
    redirect_uri = config[:redirect_uri]

    case params do
      %{"code" => code} ->
        case HubSpotOAuth.exchange_code(code, redirect_uri) do
          {:ok, {:ok, %Core.Integrations.OAuth.Token{} = token}} ->
            # Get HubSpot portal ID from the token info
            case HubSpotOAuth.get_portal_info(token.access_token) do
              {:ok, hub_id} ->
                Logger.info("Got HubSpot portal ID: #{hub_id}")

                # Extract token fields into a map for connection creation
                connection_params = %{
                  tenant_id: tenant_id,
                  provider: :hubspot,
                  status: :active,
                  external_system_id: to_string(hub_id),
                  access_token: token.access_token,
                  refresh_token: token.refresh_token,
                  expires_at: token.expires_at,
                  token_type: token.token_type,
                  scopes: config[:scopes] || []
                }

                case Connections.create_connection(connection_params) do
                  {:ok, connection} ->
                    Logger.info(
                      "Successfully created HubSpot connection: #{inspect(connection, pretty: true)}"
                    )

                    conn
                    |> put_status(:ok)
                    |> json(%{
                      status: "success",
                      message: "Successfully connected to HubSpot"
                    })

                  {:error, reason} ->
                    Logger.error(
                      "Failed to create HubSpot connection: #{inspect(reason)}"
                    )

                    conn
                    |> put_status(:internal_server_error)
                    |> json(%{
                      status: "error",
                      message: "Failed to complete HubSpot integration"
                    })
                end

              {:error, reason} ->
                Logger.error(
                  "Failed to get HubSpot portal ID: #{inspect(reason)}"
                )

                conn
                |> put_status(:internal_server_error)
                |> json(%{
                  status: "error",
                  message: "Failed to complete HubSpot integration"
                })
            end

          {:ok, {:error, reason}} ->
            Logger.error(
              "Failed to exchange code for token: #{inspect(reason)}"
            )

            conn
            |> put_status(:internal_server_error)
            |> json(%{
              status: "error",
              message: "Failed to complete HubSpot integration"
            })

          {:error, reason} ->
            Logger.error(
              "Failed to exchange code for token: #{inspect(reason)}"
            )

            conn
            |> put_status(:internal_server_error)
            |> json(%{
              status: "error",
              message: "Failed to complete HubSpot integration"
            })
        end

      %{"error" => error, "error_description" => description} ->
        Logger.error("HubSpot OAuth error: #{error} - #{description}")

        conn
        |> put_status(:bad_request)
        |> json(%{
          status: "error",
          message: "HubSpot authorization failed: #{description}"
        })

      _ ->
        Logger.error("Invalid HubSpot callback params: #{inspect(params)}")

        conn
        |> put_status(:bad_request)
        |> json(%{status: "error", message: "Invalid HubSpot callback"})
    end
  end

  @doc """
  Disconnects the HubSpot integration.
  """
  def disconnect(conn, _params) do
    tenant_id = conn.assigns.current_user.tenant_id

    case Connections.get_connection(tenant_id, :hubspot) do
      {:ok, connection} ->
        case Connections.delete_connection(connection) do
          {:ok, _} ->
            conn
            |> put_status(:ok)
            |> json(%{
              status: "success",
              message: "Successfully disconnected from HubSpot"
            })

          {:error, reason} ->
            Logger.error(
              "Failed to delete HubSpot connection: #{inspect(reason)}"
            )

            conn
            |> put_status(:internal_server_error)
            |> json(%{
              status: "error",
              message: "Failed to disconnect from HubSpot"
            })
        end

      {:error, :not_found} ->
        conn
        |> put_status(:not_found)
        |> json(%{
          status: "error",
          message: "No active HubSpot connection found"
        })
    end
  end
end
