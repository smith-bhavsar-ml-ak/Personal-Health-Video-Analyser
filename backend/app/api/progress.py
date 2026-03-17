from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.deps import get_current_user
from app.db.database import get_db
from app.db import crud
from app.db.models import User

router = APIRouter()


@router.get("/summary")
async def progress_summary(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await crud.get_progress_summary(db, current_user.id)


@router.get("/form-trend")
async def form_trend(
    limit: int = 20,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await crud.get_form_score_trend(db, current_user.id, limit=limit)


@router.get("/exercise-stats")
async def exercise_stats(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    return await crud.get_exercise_stats(db, current_user.id)


@router.get("/weight")
async def weight_history(
    limit: int = 90,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    logs = await crud.get_weight_history(db, current_user.id, limit=limit)
    return [{"id": w.id, "weight_kg": w.weight_kg, "logged_at": w.logged_at.isoformat()} for w in logs]


@router.post("/weight")
async def log_weight(
    body: dict,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    weight_kg = float(body["weight_kg"])
    entry = await crud.log_weight(db, current_user.id, weight_kg)
    return {"id": entry.id, "weight_kg": entry.weight_kg, "logged_at": entry.logged_at.isoformat()}
