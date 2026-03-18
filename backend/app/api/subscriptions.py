import logging
from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from app.auth.deps import get_current_user
from app.db.database import get_db
from app.db import crud
from app.db.models import User

logger = logging.getLogger(__name__)
router = APIRouter()

_TIER_FEATURES = {
    "free": {
        "analyses_per_month": 10,
        "exercises": 5,
        "ai_coaching": True,
        "walking_tracking": True,
        "share_card": False,
        "plan_generation": True,
        "voice_queries": 5,
    },
    "pro": {
        "analyses_per_month": 100,
        "exercises": 20,
        "ai_coaching": True,
        "walking_tracking": True,
        "share_card": True,
        "plan_generation": True,
        "voice_queries": 50,
        "priority_support": True,
    },
    "elite": {
        "analyses_per_month": -1,
        "exercises": -1,
        "ai_coaching": True,
        "walking_tracking": True,
        "share_card": True,
        "plan_generation": True,
        "voice_queries": -1,
        "priority_support": True,
        "custom_plans": True,
        "export_data": True,
    },
}


class UpgradeTierRequest(BaseModel):
    tier: str  # pro | elite
    # In a real app this would include Stripe payment_intent_id etc.
    # For now we trust the client (MVP / demo mode)


@router.get("/me")
async def get_my_subscription(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """Return current subscription status and quota."""
    sub = await crud.get_or_create_subscription(db, current_user.id)
    quota = await crud.check_analysis_quota(db, current_user.id)
    return {
        "tier": sub.tier,
        "is_active": sub.is_active,
        "started_at": sub.started_at.isoformat(),
        "expires_at": sub.expires_at.isoformat() if sub.expires_at else None,
        "analyses_used": quota["used"],
        "analyses_limit": quota["limit"],
        "features": _TIER_FEATURES.get(sub.tier, _TIER_FEATURES["free"]),
    }


@router.post("/upgrade")
async def upgrade_subscription(
    body: UpgradeTierRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Upgrade/downgrade the user's tier.
    MVP: no payment gateway — just updates the tier directly.
    Production: verify Stripe webhook before calling upsert_subscription.
    """
    if body.tier not in ("free", "pro", "elite"):
        from fastapi import HTTPException
        raise HTTPException(status_code=400, detail="Invalid tier")

    from datetime import datetime, timedelta
    expires_at = datetime.utcnow() + timedelta(days=30) if body.tier != "free" else None
    sub = await crud.upsert_subscription(db, current_user.id, body.tier, expires_at)
    return {
        "tier": sub.tier,
        "expires_at": sub.expires_at.isoformat() if sub.expires_at else None,
        "features": _TIER_FEATURES.get(sub.tier, _TIER_FEATURES["free"]),
    }
