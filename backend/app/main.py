import logging
import os
import sys
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pythonjsonlogger import jsonlogger
from slowapi import _rate_limit_exceeded_handler
from slowapi.errors import RateLimitExceeded

from app.core.limiter import limiter
from app.db.database import init_db
from app.api.router import api_router
from app.analysis.bilstm_analyser import preload_model


def _setup_logging() -> None:
    handler = logging.StreamHandler(sys.stdout)
    formatter = jsonlogger.JsonFormatter(
        fmt="%(asctime)s %(levelname)s %(name)s %(message)s",
        datefmt="%Y-%m-%dT%H:%M:%SZ",
        rename_fields={"asctime": "timestamp", "levelname": "level", "name": "logger"},
    )
    handler.setFormatter(formatter)
    root = logging.getLogger()
    root.handlers = [handler]
    root.setLevel(logging.INFO)
    # Silence noisy third-party loggers
    for _noisy in ("uvicorn.access", "sqlalchemy.engine", "watchfiles.main"):
        logging.getLogger(_noisy).setLevel(logging.WARNING)


_setup_logging()
logger = logging.getLogger(__name__)

ALLOWED_ORIGINS = [
    o.strip()
    for o in os.getenv("ALLOWED_ORIGINS", "http://localhost:3000").split(",")
    if o.strip()
]


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Starting up Personal Health Video Analyser backend...")
    logger.info("CORS allowed origins: %s", ALLOWED_ORIGINS)
    await init_db()
    logger.info("Database initialised.")
    preload_model()
    logger.info("Ready.")
    yield
    logger.info("Shutting down.")


app = FastAPI(
    title="Personal Health Video Analyzer",
    version="0.1.0",
    lifespan=lifespan,
)

# Rate limiting
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(api_router, prefix="/api/v1")


@app.get("/api/v1/health")
async def health():
    return {"status": "ok", "version": "0.1.0"}
