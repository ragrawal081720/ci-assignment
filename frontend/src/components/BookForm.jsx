import { useEffect, useState } from "react";

const EMPTY_FORM = {
  title: "",
  author: "",
  genre: "",
};

export default function BookForm({ selectedBook, onSubmit, onCancel, busy }) {
  const [form, setForm] = useState(EMPTY_FORM);

  useEffect(() => {
    if (selectedBook) {
      setForm({
        title: selectedBook.title,
        author: selectedBook.author,
        genre: selectedBook.genre,
      });
      return;
    }
    setForm(EMPTY_FORM);
  }, [selectedBook]);

  function handleChange(event) {
    const { name, value } = event.target;
    setForm((prev) => ({ ...prev, [name]: value }));
  }

  async function handleSubmit(event) {
    event.preventDefault();
    await onSubmit(form);
    if (!selectedBook) {
      setForm(EMPTY_FORM);
    }
  }

  return (
    <form className="panel" onSubmit={handleSubmit}>
      <h2>{selectedBook ? "Edit Book" : "Add Book"}</h2>

      <label>
        Title
        <input name="title" value={form.title} onChange={handleChange} required maxLength={255} />
      </label>

      <label>
        Author
        <input name="author" value={form.author} onChange={handleChange} required maxLength={255} />
      </label>

      <label>
        Genre
        <input name="genre" value={form.genre} onChange={handleChange} required maxLength={120} />
      </label>

      <div className="form-actions">
        <button type="submit" disabled={busy}>
          {busy ? "Saving..." : selectedBook ? "Update Book" : "Create Book"}
        </button>
        {selectedBook && (
          <button type="button" className="secondary" onClick={onCancel} disabled={busy}>
            Cancel
          </button>
        )}
      </div>
    </form>
  );
}
