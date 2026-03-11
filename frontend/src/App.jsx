import { useEffect, useMemo, useState } from "react";

import { createBook, deleteBook, getBookById, listBooks, updateBook } from "./api/booksApi";
import BookForm from "./components/BookForm";
import BooksTable from "./components/BooksTable";

export default function App() {
  const [books, setBooks] = useState([]);
  const [selectedBook, setSelectedBook] = useState(null);
  const [busy, setBusy] = useState(false);
  const [status, setStatus] = useState("Loading books...");

  const selectedBookId = useMemo(() => selectedBook?.id ?? null, [selectedBook]);

  async function refreshBooks(nextStatus = "Ready") {
    const data = await listBooks();
    setBooks(data);
    setStatus(nextStatus);
  }

  useEffect(() => {
    async function bootstrap() {
      try {
        await refreshBooks();
      } catch (error) {
        setStatus(error.message);
      }
    }

    bootstrap();
  }, []);

  async function handleSubmit(payload) {
    setBusy(true);
    try {
      let nextStatus = "Ready";
      if (selectedBook) {
        await updateBook(selectedBook.id, payload);
        nextStatus = "Book updated";
      } else {
        await createBook(payload);
        nextStatus = "Book created";
      }
      setSelectedBook(null);
      await refreshBooks(nextStatus);
    } catch (error) {
      setStatus(error.message);
    } finally {
      setBusy(false);
    }
  }

  async function handleDelete(bookId) {
    setBusy(true);
    try {
      await deleteBook(bookId);
      if (selectedBookId === bookId) {
        setSelectedBook(null);
      }
      await refreshBooks("Book deleted");
    } catch (error) {
      setStatus(error.message);
    } finally {
      setBusy(false);
    }
  }

  async function handleSelect(book) {
    setBusy(true);
    try {
      const fullBook = await getBookById(book.id);
      setSelectedBook(fullBook);
      setStatus(`Editing book ${fullBook.id}`);
    } catch (error) {
      setStatus(error.message);
    } finally {
      setBusy(false);
    }
  }

  return (
    <main className="page">
      <header>
        <h1>Books CRUD</h1>
        <p className="muted">Simple full-stack app with FastAPI, Postgres, and Redis cache.</p>
      </header>

      <p className="status">Status: {status}</p>

      <div className="layout">
        <BookForm
          selectedBook={selectedBook}
          onSubmit={handleSubmit}
          onCancel={() => setSelectedBook(null)}
          busy={busy}
        />

        <BooksTable
          books={books}
          selectedBookId={selectedBookId}
          onSelect={handleSelect}
          onDelete={handleDelete}
          busy={busy}
        />
      </div>
    </main>
  );
}
