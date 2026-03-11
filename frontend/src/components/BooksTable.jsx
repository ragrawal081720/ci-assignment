export default function BooksTable({ books, selectedBookId, onSelect, onDelete, busy }) {
  return (
    <section className="panel">
      <h2>Books</h2>
      {books.length === 0 ? (
        <p className="muted">No books found. Add your first book.</p>
      ) : (
        <table>
          <thead>
            <tr>
              <th>ID</th>
              <th>Title</th>
              <th>Author</th>
              <th>Genre</th>
              <th>Actions</th>
            </tr>
          </thead>
          <tbody>
            {books.map((book) => (
              <tr key={book.id} className={book.id === selectedBookId ? "selected-row" : ""}>
                <td>{book.id}</td>
                <td>{book.title}</td>
                <td>{book.author}</td>
                <td>{book.genre}</td>
                <td className="actions-cell">
                  <button className="secondary" onClick={() => onSelect(book)} disabled={busy}>
                    Edit
                  </button>
                  <button className="danger" onClick={() => onDelete(book.id)} disabled={busy}>
                    Delete
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </section>
  );
}
