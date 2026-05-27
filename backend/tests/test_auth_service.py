from backend.application.dto.requests import (
    AuthLoginRequestDto,
    AuthRegisterRequestDto,
)
from backend.application.services.auth_service import (
    AuthService,
    DuplicateUserError,
    InvalidCredentialsError,
)
from backend.infrastructure.repositories.auth_user_repository import AuthUserRepository


def _service(tmp_path):
    repo = AuthUserRepository(tmp_path / "auth_users.json")
    return AuthService(repo=repo, secret_key="test-secret")


def test_register_login_and_me_round_trip(tmp_path):
    service = _service(tmp_path)

    registered = service.register(
        AuthRegisterRequestDto(
            username="Maya",
            email="MAYA@example.com",
            password="very-secret-password",
        )
    )

    assert registered.user.email == "maya@example.com"
    assert registered.access_token

    logged_in = service.login(
        AuthLoginRequestDto(
            email="maya@example.com",
            password="very-secret-password",
        )
    )
    current_user = service.get_user_from_token(logged_in.access_token)

    assert current_user.id == registered.user.id
    assert current_user.username == "Maya"


def test_register_rejects_duplicate_email(tmp_path):
    service = _service(tmp_path)
    payload = AuthRegisterRequestDto(
        username="Maya",
        email="maya@example.com",
        password="very-secret-password",
    )

    service.register(payload)

    try:
        service.register(payload)
    except DuplicateUserError:
        pass
    else:
        raise AssertionError("duplicate email should fail")


def test_login_rejects_bad_password(tmp_path):
    service = _service(tmp_path)
    service.register(
        AuthRegisterRequestDto(
            username="Maya",
            email="maya@example.com",
            password="very-secret-password",
        )
    )

    try:
        service.login(
            AuthLoginRequestDto(
                email="maya@example.com",
                password="wrong-password",
            )
        )
    except InvalidCredentialsError:
        pass
    else:
        raise AssertionError("bad password should fail")
