from __future__ import annotations

from fastapi import HTTPException, status

from backend.application.services.auth_service import AuthService, InvalidTokenError

_auth_service = AuthService()


def optional_authenticated_user_id(authorization: str | None) -> str | None:
    if not authorization:
        return None

    scheme, _, token = authorization.partition(" ")
    if scheme.lower() != "bearer" or not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Expected bearer token.",
        )

    try:
        return _auth_service.get_user_from_token(token.strip()).id
    except InvalidTokenError as exc:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(exc),
        ) from exc
