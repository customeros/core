defmodule Core.ScraperFixtures do
  @moduledoc """
  Fixtures for scraper tests.
  """

  def valid_html do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <title>Example Domain</title>
    </head>
    <body>
      <h1>Example Domain</h1>
      <p>This domain is for use in illustrative examples.</p>
      <p>You may use this domain in literature without prior coordination or asking for permission.</p>
      <a href="https://example.com/page1">Page 1</a>
      <a href="https://example.com/page2">Page 2</a>
    </body>
    </html>
    """
  end

  def invalid_html do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <title>Invalid HTML</title>
    </head>
    <body>
      <p>This is an unclosed paragraph
      <a href="https://example.com">Link</a>
    </body>
    """
  end

  def html_with_navigation do
    """
    <!DOCTYPE html>
    <html>
    <head>
      <title>Example with Navigation</title>
    </head>
    <body>
      <nav>
        <ul>
          <li><a href="/home">Home</a></li>
          <li><a href="/about">About</a></li>
          <li><a href="/contact">Contact</a></li>
        </ul>
      </nav>
      <main>
        <h1>Main Content</h1>
        <p>This is the main content of the page.</p>
      </main>
      <footer>
        <p>Copyright © 2024</p>
        <ul>
          <li><a href="/privacy">Privacy Policy</a></li>
          <li><a href="/terms">Terms of Service</a></li>
        </ul>
      </footer>
    </body>
    </html>
    """
  end
end
