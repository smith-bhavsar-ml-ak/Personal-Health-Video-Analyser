from pydantic import BaseModel


class RegisterRequest(BaseModel):
    email: str
    password: str


class LoginRequest(BaseModel):
    email: str
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str
    user_id: str
    email: str


class UserResponse(BaseModel):
    user_id: str
    email: str


class ProfileData(BaseModel):
    display_name: str | None = None
    date_of_birth: str | None = None
    gender: str | None = None
    height_cm: float | None = None
    weight_kg: float | None = None
    target_weight_kg: float | None = None
    fitness_level: str | None = None
    primary_goal: str | None = None
    weekly_workout_target: int | None = None
    equipment: str | None = None
    activity_level: str | None = None
    injuries: str | None = None
    unit_system: str = "metric"

    class Config:
        from_attributes = True
