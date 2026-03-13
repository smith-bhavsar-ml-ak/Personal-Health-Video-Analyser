from fastapi import APIRouter
from app.api import sessions, voice
from app.auth.router import router as auth_router

api_router = APIRouter()
api_router.include_router(auth_router,      prefix="/auth",     tags=["auth"])
api_router.include_router(sessions.router,  prefix="/sessions", tags=["sessions"])
api_router.include_router(voice.router,     prefix="/sessions", tags=["voice"])
