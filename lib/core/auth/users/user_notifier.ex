defmodule Core.Auth.Users.UserNotifier do
  import Swoosh.Email

  import Phoenix.Component

  alias Core.Mailer

  def deliver(opts) do
    email =
      new(
        from: {"CustomerOS", "notification@app.customeros.ai"},
        to: opts[:to],
        subject: opts[:subject],
        html_body: opts[:html_body],
        text_body: opts[:text_body]
      )
      |> Swoosh.Email.put_provider_option(:track_links, "None")

    email_with_options =
      case opts[:message_stream] do
        nil ->
          email

        _ ->
          Swoosh.Email.put_provider_option(
            email,
            :message_stream,
            opts[:message_stream]
          )
      end

    with {:ok, _metadata} <- Mailer.deliver(email_with_options) do
      {:ok, email}
    end
  end

  def deliver_update_email_instructions(user, url) do
    {html, text} = render_content(&email_update_content/1, %{url: url})

    deliver(
      to: user.email,
      subject: "Confirm your new email on CustomerOS",
      html_body: html,
      text_body: text
    )
  end

  def deliver_login_link(user, url) do
    {html, text} = render_content(&login_content/1, %{url: url})

    deliver(
      to: user.email,
      subject: "Sign in to CustomerOS",
      html_body: html,
      text_body: text,
      message_stream: "magic-link"
    )
  end

  def deliver_register_link(user, url) do
    {html, text} = render_content(&register_content/1, %{url: url})

    deliver(
      to: user.email,
      subject: "Create your account on CustomerOS",
      html_body: html,
      text_body: text,
      message_stream: "magic-link"
    )
  end

  defp email_layout(assigns) do
    ~H"""
    <!DOCTYPE html>
    <html lang="en">
      <head>
        <meta charset="UTF-8" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
        <style>
          body {
            font-family: system-ui, sans-serif;
            margin: 3em auto;
            overflow-wrap: break-word;
            word-break: break-all;
            max-width: 1024px;
            padding: 0 1em;
          }
        </style>
      </head>
      <body>
        {render_slot(@inner_block)}
      </body>
    </html>
    """
  end

  def email_update_content(assigns) do
    ~H"""
    <.email_layout>
      <p>Click the link below to confirm this as your new email.</p>

      <a href={@url}>{@url}</a>

      <p>If you didn't request this email, feel free to ignore this.</p>
    </.email_layout>
    """
  end

  def register_content(assigns) do
    ~H"""
    <.email_layout>
      <h1>Hey there!</h1>

      <p>Please use this link to create your account at CustomerOS:</p>

      <a href={@url}>{@url}</a>

      <p>If you didn't request this email, feel free to ignore this.</p>
    </.email_layout>
    """
  end

  def login_content(assigns) do
    ~H"""
    <.email_layout>
      <h1>Hey there!</h1>

      <p>Please use this link to sign in to CustomerOS:</p>

      <a href={@url}>{@url}</a>

      <p>If you didn't request this email, feel free to ignore this.</p>
    </.email_layout>
    """
  end

  defp heex_to_html(template) do
    template
    |> Phoenix.HTML.Safe.to_iodata()
    |> IO.iodata_to_binary()
  end

  defp html_to_text(html) do
    html
    |> Floki.parse_document!()
    |> Floki.find("body")
    |> Floki.text(sep: "\n\n")
  end

  defp render_content(content_fn, assigns) do
    template = content_fn.(assigns)
    html = heex_to_html(template)
    text = html_to_text(html)

    {html, text}
  end
end
