from fastapi import APIRouter, Depends, Response, status
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.schemas.book import BookCreate, BookResponse, BookUpdate
from app.services.book_service import create_book, delete_book, get_book_by_id, list_books, update_book

router = APIRouter(prefix="/books", tags=["books"])


@router.post("", response_model=BookResponse, status_code=status.HTTP_201_CREATED)
def create_book_route(payload: BookCreate, db: Session = Depends(get_db)) -> BookResponse:
    return create_book(db, payload)


@router.get("", response_model=list[BookResponse])
def list_books_route(db: Session = Depends(get_db)) -> list[BookResponse]:
    return list_books(db)


@router.get("/{book_id}", response_model=BookResponse)
def get_book_route(book_id: int, db: Session = Depends(get_db)) -> BookResponse:
    return get_book_by_id(db, book_id)


@router.put("/{book_id}", response_model=BookResponse)
def update_book_route(book_id: int, payload: BookUpdate, db: Session = Depends(get_db)) -> BookResponse:
    return update_book(db, book_id, payload)


@router.delete("/{book_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_book_route(book_id: int, db: Session = Depends(get_db)) -> Response:
    delete_book(db, book_id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)
