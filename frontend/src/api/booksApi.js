const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || "http://localhost:8000/api";

async function request(path, options = {}) {
  const response = await fetch(`${API_BASE_URL}${path}`, {
    headers: {
      "Content-Type": "application/json",
      ...(options.headers || {}),
    },
    ...options,
  });

  if (!response.ok) {
    const data = await response.json().catch(() => ({}));
    const message = data?.detail || `Request failed with status ${response.status}`;
    throw new Error(message);
  }

  if (response.status === 204) {
    return null;
  }

  return response.json();
}

export function listBooks() {
  return request("/books");
}

export function getBookById(bookId) {
  return request(`/books/${bookId}`);
}

export function createBook(payload) {
  return request("/books", {
    method: "POST",
    body: JSON.stringify(payload),
  });
}

export function updateBook(bookId, payload) {
  return request(`/books/${bookId}`, {
    method: "PUT",
    body: JSON.stringify(payload),
  });
}

export function deleteBook(bookId) {
  return request(`/books/${bookId}`, {
    method: "DELETE",
  });
}
