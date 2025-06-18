defmodule Core.Utils.Media.Images do
  @moduledoc """
  Handles image processing, storage, and CDN management.

  This module provides functionality for:
  * Downloading images from URLs
  * Storing images in R2 (S3-compatible storage)
  * Managing image content types and extensions
  * Generating CDN URLs for stored images
  * Handling image persistence and retrieval

  It integrates with R2 storage and provides a robust interface
  for managing images throughout the application, including
  proper error handling and content type management.
  """

  require Logger

  @err_timeout {:error, :timeout}
  @err_not_found {:error, :image_not_found}

  @type storage_opts :: %{
          optional(:generate_name) => boolean(),
          optional(:path) => String.t()
        }

  defp r2_config do
    Application.get_env(:core, :r2)
  end

  defp images_config do
    get_in(r2_config(), [:images]) || raise "R2 images configuration is missing"
  end

  defp images_bucket do
    get_in(images_config(), [:bucket]) ||
      raise "R2 images bucket is not configured"
  end

  @doc """
  Downloads an image from a URL and stores it in R2.
  Returns {:ok, storage_key} or {:error, reason}

  ## Options

    * `:generate_name` - If true, generates a random name for the file while preserving extension
    * `:path` - The path prefix where the image should be stored (e.g. "images/avatars/")

  ## Examples

      iex> download_and_store("https://example.com/image.jpg")
      {:ok, "images/image.jpg"}

      iex> download_and_store("https://example.com/image.jpg", %{generate_name: true, path: "images/avatars/"})
      {:ok, "images/avatars/abc123def456.jpg"}
  """
  def download_and_store(url, opts \\ %{}) do
    with {:ok, image_data} <- download_image(url),
         content_type <- get_content_type(url) |> handle_content_type(url) do
      store_image(image_data, content_type, url, opts)
    end
  end

  @doc """
  Downloads an image from a URL.
  Returns {:ok, binary_data} or {:error, reason}
  """
  def download_image(url) do
    case Finch.build(:get, url, [], []) |> Finch.request(Core.Finch) do
      {:ok, %{status: 200, body: body}} ->
        {:ok, body}

      {:ok, %{status: 404}} ->
        @err_not_found

      {:ok, %{status: status}} ->
        {:error, "HTTP request failed with status #{status}"}

      {:error, %Mint.TransportError{reason: :timeout}} ->
        @err_timeout

      {:error, reason} ->
        {:error, "HTTP request failed: #{inspect(reason)}"}
    end
  end

  @doc """
  Stores an image in R2.
  Returns {:ok, storage_key} or {:error, reason}

  ## Options

    * `:generate_name` - If true, generates a random name for the file while preserving extension
    * `:path` - The path prefix where the image should be stored (e.g. "companies" or "users/avatars")
  """
  def store_image(image_data, content_type, original_url, opts \\ %{}) do
    path =
      case Map.get(opts, :path, "") do
        "" -> ""
        path -> String.trim_trailing(path, "/") <> "/"
      end

    generate_name = Map.get(opts, :generate_name, false)

    storage_key =
      if generate_name do
        extension = get_extension(original_url)
        "#{path}#{Core.Utils.IdGenerator.generate_id_21("img")}#{extension}"
      else
        filename = Path.basename(original_url)
        "#{path}#{filename}"
      end

    config = r2_config()

    case ExAws.S3.put_object(images_bucket(), storage_key, image_data,
           content_type: content_type
         )
         |> ExAws.request(config) do
      {:ok, _} -> {:ok, storage_key}
      {:error, reason} -> {:error, "Failed to store image: #{inspect(reason)}"}
    end
  end

  @doc """
  Gets the content type of an image from its URL.
  Returns {:ok, content_type} or {:error, reason}
  """
  @spec get_content_type(String.t()) :: {:ok, String.t()} | {:error, term()}
  def get_content_type(url) do
    case Finch.build(:head, url, [], []) |> Finch.request(Core.Finch) do
      {:ok, %{headers: headers}} ->
        case List.keyfind(headers, "content-type", 0) do
          {"content-type", content_type} -> {:ok, content_type}
          nil -> {:error, "No content type found"}
        end

      {:error, reason} ->
        {:error, "Failed to get content type: #{inspect(reason)}"}
    end
  end

  @doc """
  Gets the CDN URL for a storage key.
  Handles CDN domains that may have https:// prefix and trailing slashes.
  """
  def get_cdn_url(storage_key)
      when is_binary(storage_key) and storage_key != "" do
    case Application.get_env(:core, :r2)[:images][:cdn_domain] do
      nil ->
        nil

      cdn_domain ->
        # Strip any https:// prefix and trailing slash from the domain
        clean_cdn_domain =
          cdn_domain
          |> String.replace(~r/^https?:\/\//, "")
          |> String.trim_trailing("/")

        # Ensure storage key doesn't have leading slash
        clean_key = String.trim_leading(storage_key, "/")

        "https://#{clean_cdn_domain}/#{clean_key}"
    end
  end

  def get_cdn_url(_), do: nil

  # Private functions

  defp get_extension(url) do
    case Path.extname(url) do
      # Default to .jpg if no extension found
      "" -> ".jpg"
      ext -> ext
    end
  end

  # Private helper to handle content type
  defp handle_content_type({:ok, content_type}, _url), do: content_type

  defp handle_content_type({:error, _}, url) do
    # Try to determine content type from URL extension
    case Path.extname(url) do
      ".png" -> "image/png"
      ".gif" -> "image/gif"
      ".webp" -> "image/webp"
      ".svg" -> "image/svg+xml"
      # Default to JPEG
      _ -> "image/jpeg"
    end
  end
end
