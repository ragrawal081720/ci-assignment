from fastapi import HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.cache.redis_client import cache
from app.models.book import Book
from app.schemas.book import BookCreate, BookResponse, BookUpdate


def create_book(db: Session, payload: BookCreate) -> BookResponse:
    book = Book(**payload.model_dump())
    db.add(book)
    db.commit()
    db.refresh(book)
    cache.invalidate_books_list()
    return BookResponse.model_validate(book)


def list_books(db: Session) -> list[BookResponse]:
    cached = cache.get_books_list()
    if cached is not None:
        return cached

    books = db.execute(select(Book).order_by(Book.id.asc())).scalars().all()
    response = [BookResponse.model_validate(book) for book in books]
    cache.set_books_list(response)
    return response


def get_book_by_id(db: Session, book_id: int) -> BookResponse:
    book = db.get(Book, book_id)
    if not book:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Book not found")
    return BookResponse.model_validate(book)


def update_book(db: Session, book_id: int, payload: BookUpdate) -> BookResponse:
    book = db.get(Book, book_id)
    if not book:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Book not found")

    update_data = payload.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(book, field, value)

    db.add(book)
    db.commit()
    db.refresh(book)
    cache.invalidate_books_list()
    return BookResponse.model_validate(book)


def delete_book(db: Session, book_id: int) -> None:
    book = db.get(Book, book_id)
    if not book:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Book not found")

    db.delete(book)
    db.commit()
    cache.invalidate_books_list()
