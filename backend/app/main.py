from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from prometheus_fastapi_instrumentator import Instrumentator

from app.api.books import router as books_router
from app.api.health import router as health_router
from app.config import settings

app = FastAPI(title=settings.app_name, debug=settings.debug)

app.add_middleware(
    CORSMiddleware,
    allow_origins=[settings.frontend_origin],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health_router, prefix=settings.api_prefix)
app.include_router(books_router, prefix=settings.api_prefix)

Instrumentator().instrument(app).expose(app, endpoint="/metrics", include_in_schema=False)
