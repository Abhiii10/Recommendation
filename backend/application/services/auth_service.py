from __future__ import annotations

import base64
from datetime import datetime, timedelta, timezone
import hashlib
import hmac
import json
import secrets
import uuid

from backend.application.dto.requests import (
    AuthLoginRequestDto,
    AuthRegisterRequestDto,
)
from backend.application.dto.responses import AuthTokenResponseDto, AuthUserDto
from backend.core.config import settings
from backend.domain.entities.auth_user import AuthUser
from backend.infrastructure.repositories.auth_user_repository import AuthUserRepository


class AuthServiceError(Exception):
    pass


class DuplicateUserError(AuthServiceError):
    pass


class InvalidCredentialsError(AuthServiceError):
    pass


class InvalidTokenError(AuthServiceError):
    pass


class AuthService:
    _hash_iterations = 120_000

    def __init__(
        self,
        repo: AuthUserRepository | None = None,
        secret_key: str | None = None,
    ):
        self._repo = repo or AuthUserRepository()
        self._secret_key = secret_key or settings.auth_secret_key

    def register(self, request: AuthRegisterRequestDto) -> AuthTokenResponseDto:
        email = self._normalize_email(request.email)
        username = request.username.strip()

        if self._repo.get_by_email(email) is not None:
            raise DuplicateUserError("An account with this email already exists.")

        user = AuthUser(
            id=f"user_{uuid.uuid4().hex}",
            username=username,
            email=email,
            password_hash=self._hash_password(request.password),
        )

        self._repo.add(user)
        return self._token_response(user)

    def login(self, request: AuthLoginRequestDto) -> AuthTokenResponseDto:
        user = self._repo.get_by_email(request.email)

        if user is None or not self._verify_password(
            request.password,
            user.password_hash,
        ):
            raise InvalidCredentialsError("Invalid email or password.")

        return self._token_response(user)

    def get_user_from_token(self, token: str) -> AuthUserDto:
        payload = self._decode_token(token)
        user_id = str(payload.get("sub", ""))

        if not user_id:
            raise InvalidTokenError("Token subject is missing.")

        user = self._repo.get_by_id(user_id)
        if user is None:
            raise InvalidTokenError("Token user does not exist.")

        return self._public_user(user)

    def _token_response(self, user: AuthUser) -> AuthTokenResponseDto:
        return AuthTokenResponseDto(
            access_token=self._create_access_token(user),
            user=self._public_user(user),
        )

    def _create_access_token(self, user: AuthUser) -> str:
        expires_at = datetime.now(timezone.utc) + timedelta(
            minutes=settings.auth_access_token_expire_minutes
        )
        payload = {
            "sub": user.id,
            "email": user.email,
            "exp": int(expires_at.timestamp()),
        }

        return self._encode_token(payload)

    def _encode_token(self, payload: dict[str, object]) -> str:
        header = {"alg": "HS256", "typ": "JWT"}
        signing_input = ".".join(
            [
                self._base64url_json(header),
                self._base64url_json(payload),
            ]
        )
        signature = hmac.new(
            self._secret_key.encode("utf-8"),
            signing_input.encode("utf-8"),
            hashlib.sha256,
        ).digest()

        return f"{signing_input}.{self._base64url_encode(signature)}"

    def _decode_token(self, token: str) -> dict[str, object]:
        try:
            header_part, payload_part, signature_part = token.split(".")
            signing_input = f"{header_part}.{payload_part}"
            expected_signature = hmac.new(
                self._secret_key.encode("utf-8"),
                signing_input.encode("utf-8"),
                hashlib.sha256,
            ).digest()

            if not hmac.compare_digest(
                self._base64url_encode(expected_signature),
                signature_part,
            ):
                raise InvalidTokenError("Token signature is invalid.")

            header = json.loads(self._base64url_decode(header_part))
            if header.get("alg") != "HS256":
                raise InvalidTokenError("Token algorithm is unsupported.")

            payload = json.loads(self._base64url_decode(payload_part))
            expires_at = int(payload.get("exp", 0))
            if expires_at < int(datetime.now(timezone.utc).timestamp()):
                raise InvalidTokenError("Token has expired.")

            return payload
        except InvalidTokenError:
            raise
        except Exception as exc:
            raise InvalidTokenError("Token is invalid.") from exc

    def _hash_password(self, password: str) -> str:
        salt = secrets.token_hex(16)
        digest = hashlib.pbkdf2_hmac(
            "sha256",
            password.encode("utf-8"),
            salt.encode("utf-8"),
            self._hash_iterations,
        ).hex()
        return f"pbkdf2_sha256${self._hash_iterations}${salt}${digest}"

    def _verify_password(self, password: str, password_hash: str) -> bool:
        try:
            algorithm, iterations, salt, stored_digest = password_hash.split("$")
            if algorithm != "pbkdf2_sha256":
                return False

            digest = hashlib.pbkdf2_hmac(
                "sha256",
                password.encode("utf-8"),
                salt.encode("utf-8"),
                int(iterations),
            ).hex()
            return hmac.compare_digest(digest, stored_digest)
        except Exception:
            return False

    def _public_user(self, user: AuthUser) -> AuthUserDto:
        return AuthUserDto(
            id=user.id,
            username=user.username,
            email=user.email,
        )

    def _normalize_email(self, email: str) -> str:
        return email.strip().lower()

    def _base64url_json(self, payload: dict[str, object]) -> str:
        raw = json.dumps(payload, separators=(",", ":"), sort_keys=True).encode(
            "utf-8"
        )
        return self._base64url_encode(raw)

    def _base64url_encode(self, raw: bytes) -> str:
        return base64.urlsafe_b64encode(raw).decode("utf-8").rstrip("=")

    def _base64url_decode(self, value: str) -> str:
        padding = "=" * (-len(value) % 4)
        return base64.urlsafe_b64decode(f"{value}{padding}").decode("utf-8")
