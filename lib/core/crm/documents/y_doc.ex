defmodule Core.Crm.Documents.YDoc do
  use Core.Crm.Documents.YEcto,
    repo: Core.Repo,
    schema: Core.Crm.Documents.DocumentWrite
end

defmodule Core.Crm.Documents.EctoPersistence do
  @behaviour Yex.Sync.SharedDoc.PersistenceBehaviour
  @impl true
  def bind(_state, doc_name, doc) do
    ecto_doc = Core.Crm.Documents.YDoc.get_y_doc(doc_name)

    {:ok, new_updates} = Yex.encode_state_as_update(doc)
    Core.Crm.Documents.YDoc.insert_update(doc_name, new_updates)

    Yex.apply_update(doc, Yex.encode_state_as_update!(ecto_doc))
  end

  @impl true
  def unbind(_state, _doc_name, _doc) do
    :ok
  end

  @impl true
  def update_v1(_state, update, doc_name, _doc) do
    Core.Crm.Documents.YDoc.insert_update(doc_name, update)
    :ok
  end
end
