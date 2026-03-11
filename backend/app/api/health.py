from fastapi import APIRouter
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError

from app.cache.redis_client import cache
from app.db.session import SessionLocal

router = APIRouter(prefix="/health", tags=["health"])


@router.get("")
def health_check() -> dict[str, str]:
    db_status = "down"
    redis_status = "down"

    db = SessionLocal()
    try:
        db.execute(text("SELECT 1"))
        db_status = "up"
    except SQLAlchemyError:
        db_status = "down"
    finally:
        db.close()

    redis_status = "up" if cache.ping() else "down"

    overall = "ok" if db_status == "up" and redis_status == "up" else "degraded"
    return {
        "status": overall,
        "database": db_status,
        "redis": redis_status,
    }
