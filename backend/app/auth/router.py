from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.database import get_db
from app.db import crud
from app.auth.jwt import hash_password, verify_password, create_access_token
from app.auth.deps import get_current_user
from app.db.models import User
from app.schemas.auth import RegisterRequest, LoginRequest, TokenResponse, UserResponse, ProfileData

router = APIRouter(tags=["auth"])


@router.post("/register", response_model=TokenResponse, status_code=201)
async def register(body: RegisterRequest, db: AsyncSession = Depends(get_db)):
    if len(body.password) < 8:
        raise HTTPException(status_code=422, detail="Password must be at least 8 characters")
    existing = await crud.get_user_by_email(db, body.email)
    if existing:
        raise HTTPException(status_code=409, detail="Email already registered")
    user = await crud.create_user(db, body.email, hash_password(body.password))
    token = create_access_token(user.id)
    return TokenResponse(access_token=token, token_type="bearer", user_id=user.id, email=user.email)


@router.post("/login", response_model=TokenResponse)
async def login(body: LoginRequest, db: AsyncSession = Depends(get_db)):
    user = await crud.get_user_by_email(db, body.email)
    if not user or not verify_password(body.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
        )
    token = create_access_token(user.id)
    return TokenResponse(access_token=token, token_type="bearer", user_id=user.id, email=user.email)


@router.get("/me", response_model=UserResponse)
async def me(current_user: User = Depends(get_current_user)):
    return UserResponse(user_id=current_user.id, email=current_user.email)


@router.get("/profile", response_model=ProfileData)
async def get_profile(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    profile = await crud.get_profile(db, current_user.id)
    if profile is None:
        return ProfileData()
    return profile


@router.put("/profile", response_model=ProfileData)
async def update_profile(
    body: ProfileData,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    data = body.model_dump(exclude_none=False)
    profile = await crud.upsert_profile(db, current_user.id, data)
    return profile
