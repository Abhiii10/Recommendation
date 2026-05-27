from __future__ import annotations

from fastapi import APIRouter, Header, HTTPException, status

from backend.application.dto.requests import (
    AuthLoginRequestDto,
    AuthRegisterRequestDto,
)
from backend.application.dto.responses import AuthTokenResponseDto, AuthUserDto
from backend.application.services.auth_service import (
    AuthService,
    DuplicateUserError,
    InvalidCredentialsError,
    InvalidTokenError,
)

router = APIRouter()
_service = AuthService()


@router.post("/register", response_model=AuthTokenResponseDto)
def register(payload: AuthRegisterRequestDto) -> AuthTokenResponseDto:
    try:
        return _service.register(payload)
    except DuplicateUserError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(exc),
        ) from exc


@router.post("/login", response_model=AuthTokenResponseDto)
def login(payload: AuthLoginRequestDto) -> AuthTokenResponseDto:
    try:
        return _service.login(payload)
    except InvalidCredentialsError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(exc),
        ) from exc


@router.get("/me", response_model=AuthUserDto)
def me(authorization: str | None = Header(default=None)) -> AuthUserDto:
    token = _bearer_token(authorization)

    try:
        return _service.get_user_from_token(token)
    except InvalidTokenError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(exc),
        ) from exc


def _bearer_token(authorization: str | None) -> str:
    if not authorization:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing authorization header.",
        )

    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Expected bearer token.",
        )

    return token.strip()
