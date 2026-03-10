from fastapi import APIRouter
from app.api import sessions, voice

api_router = APIRouter()
api_router.include_router(sessions.router, prefix="/sessions", tags=["sessions"])
api_router.include_router(voice.router, prefix="/sessions", tags=["voice"])
