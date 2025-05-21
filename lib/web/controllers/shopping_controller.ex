defmodule Web.ShoppingController do
  use Web, :controller

  def new(conn, _params) do
    conn
    |> render_inertia("NewGrocery")
  end

  def create(conn, params) do
    
  end

  def index(conn, _params) do
  
    conn
    |> render_inertia("ListGroceries")
  end
end
