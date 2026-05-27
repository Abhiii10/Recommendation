from backend.application.dto.requests import (
    InteractionBatchRequestDto,
    InteractionRequestDto,
)
from backend.application.services import interaction_logging_service as service_module
from backend.application.services.interaction_logging_service import (
    InteractionLoggingService,
)


class FakeInteractionRepository:
    def __init__(self) -> None:
        self.items = []

    def get_all(self):
        return list(self.items)

    def add(self, interaction) -> None:
        self.items.append(interaction)


def test_log_normalizes_event_type_and_adds_timestamp(monkeypatch):
    repo = FakeInteractionRepository()
    monkeypatch.setattr(
        service_module,
        "build_interaction_repository",
        lambda: repo,
    )

    service = InteractionLoggingService()
    service.log(
        InteractionRequestDto(
            user_id="user-1",
            destination_id="dest-1",
            event_type=" SAVE ",
            value=2.0,
        )
    )

    assert len(repo.items) == 1
    interaction = repo.items[0]
    assert interaction.event_type == "save"
    assert interaction.value == 2.0
    assert interaction.timestamp


def test_log_ignores_unsupported_event_type(monkeypatch):
    repo = FakeInteractionRepository()
    monkeypatch.setattr(
        service_module,
        "build_interaction_repository",
        lambda: repo,
    )

    service = InteractionLoggingService()
    service.log(
        InteractionRequestDto(
            user_id="user-1",
            destination_id="dest-1",
            event_type="unknown_event",
            value=1.0,
        )
    )

    assert repo.items == []


def test_log_many_counts_only_supported_events(monkeypatch):
    repo = FakeInteractionRepository()
    monkeypatch.setattr(
        service_module,
        "build_interaction_repository",
        lambda: repo,
    )

    service = InteractionLoggingService()
    logged = service.log_many(
        InteractionBatchRequestDto(
            interactions=[
                InteractionRequestDto(
                    user_id="user-1",
                    destination_id="dest-1",
                    event_type="click",
                    value=1.0,
                ),
                InteractionRequestDto(
                    user_id="user-1",
                    destination_id="dest-2",
                    event_type="unsupported",
                    value=1.0,
                ),
            ]
        )
    )

    assert logged == 1
    assert len(repo.items) == 1
    assert repo.items[0].event_type == "click"
