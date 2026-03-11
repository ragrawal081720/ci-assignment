import json
from collections.abc import Sequence

from redis import Redis
from redis.exceptions import RedisError

from app.config import settings
from app.schemas.book import BookResponse

BOOK_LIST_CACHE_KEY = "books:list"


class RedisCache:
    def __init__(self) -> None:
        self._client = Redis.from_url(settings.redis_url, decode_responses=True)

    def ping(self) -> bool:
        try:
            return bool(self._client.ping())
        except RedisError:
            return False

    def get_books_list(self) -> list[BookResponse] | None:
        try:
            cached_payload = self._client.get(BOOK_LIST_CACHE_KEY)
            if not cached_payload:
                return None
            data = json.loads(cached_payload)
            return [BookResponse.model_validate(item) for item in data]
        except (RedisError, ValueError, TypeError):
            return None

    def set_books_list(self, books: Sequence[BookResponse]) -> None:
        try:
            serialized = json.dumps([book.model_dump(mode="json") for book in books])
            self._client.setex(BOOK_LIST_CACHE_KEY, settings.cache_ttl_seconds, serialized)
        except RedisError:
            return

    def invalidate_books_list(self) -> None:
        try:
            self._client.delete(BOOK_LIST_CACHE_KEY)
        except RedisError:
            return


cache = RedisCache()
