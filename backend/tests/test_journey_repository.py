from datetime import UTC, datetime, timedelta

from app.domain.models import Journey, JourneyStatus
from app.infrastructure.persistence.models import (
    EvidenceModel,
    JourneyAnswerModel,
    JourneyFragmentModel,
    PhotoMissionModel,
    RouteModel,
    StoryArcModel,
    StoryFragmentModel,
    UserModel,
)
from app.infrastructure.persistence.repositories import SqlAlchemyJourneyRepository


def _add_user(session, user_id: str) -> None:
    now = datetime.now(UTC)
    session.add(
        UserModel(
            id=user_id,
            username=user_id,
            password_hash=None,
            account_kind="registered",
            is_active=True,
            auth_version=1,
            created_at=now,
            updated_at=now,
        )
    )


def _journey(
    *,
    journey_id: str,
    user_id: str,
    route_id: str,
    status: JourneyStatus,
    when: datetime,
) -> Journey:
    return Journey(
        id=journey_id,
        user_id=user_id,
        route_id=route_id,
        status=status,
        current_stop_position=1,
        arrived_stop_id=None,
        started_at=when,
        updated_at=when,
        completed_at=when if status is JourneyStatus.COMPLETED else None,
    )


def test_repository_prefers_active_and_selects_latest_duplicate_completion(app):
    database = app.extensions["database"]
    session = database.session_factory()
    route = session.query(RouteModel).filter_by(slug="wukang-urban-slices").one()
    _add_user(session, "history-owner")
    repository = SqlAlchemyJourneyRepository(session)
    now = datetime.now(UTC)
    repository.add(
        _journey(
            journey_id="completed-old",
            user_id="history-owner",
            route_id=route.id,
            status=JourneyStatus.COMPLETED,
            when=now - timedelta(days=2),
        )
    )
    repository.add(
        _journey(
            journey_id="completed-new",
            user_id="history-owner",
            route_id=route.id,
            status=JourneyStatus.COMPLETED,
            when=now - timedelta(days=1),
        )
    )
    repository.add(
        _journey(
            journey_id="active-current",
            user_id="history-owner",
            route_id=route.id,
            status=JourneyStatus.ACTIVE,
            when=now - timedelta(days=3),
        )
    )
    session.commit()

    assert repository.find_active(route.id, "history-owner").id == "active-current"
    assert (
        repository.find_latest_completed(route.id, "history-owner").id
        == "completed-new"
    )
    assert repository.find_latest_completed(route.id, "different-owner") is None
    session.close()


def test_library_query_orders_activity_filters_status_and_keeps_archived_route(app):
    database = app.extensions["database"]
    session = database.session_factory()
    routes = session.query(RouteModel).order_by(RouteModel.id).limit(2).all()
    routes[0].content_status = "archived"
    _add_user(session, "library-owner")
    _add_user(session, "other-owner")
    repository = SqlAlchemyJourneyRepository(session)
    now = datetime.now(UTC)
    repository.add(
        _journey(
            journey_id="archived-completed",
            user_id="library-owner",
            route_id=routes[0].id,
            status=JourneyStatus.COMPLETED,
            when=now,
        )
    )
    repository.add(
        _journey(
            journey_id="older-active",
            user_id="library-owner",
            route_id=routes[1].id,
            status=JourneyStatus.ACTIVE,
            when=now - timedelta(hours=1),
        )
    )
    repository.add(
        _journey(
            journey_id="foreign-active",
            user_id="other-owner",
            route_id=routes[1].id,
            status=JourneyStatus.ACTIVE,
            when=now + timedelta(hours=1),
        )
    )
    session.commit()

    assert [item.id for item in repository.list_for_user("library-owner")] == [
        "archived-completed",
        "older-active",
    ]
    assert [
        item.id
        for item in repository.list_for_user(
            "library-owner", (JourneyStatus.ACTIVE,)
        )
    ] == ["older-active"]
    session.close()


def test_library_aggregation_counts_fragment_legacy_and_evidence_without_n_plus_one(app):
    database = app.extensions["database"]
    session = database.session_factory()
    fragmented_route = session.query(RouteModel).filter_by(slug="nantou-time-layers").one()
    legacy_route = session.query(RouteModel).filter_by(slug="wukang-urban-slices").one()
    fragmented_route.content_status = "archived"
    _add_user(session, "aggregate-owner")
    repository = SqlAlchemyJourneyRepository(session)
    now = datetime.now(UTC)
    fragmented = _journey(
        journey_id="fragmented-completed",
        user_id="aggregate-owner",
        route_id=fragmented_route.id,
        status=JourneyStatus.COMPLETED,
        when=now,
    )
    legacy = _journey(
        journey_id="legacy-active",
        user_id="aggregate-owner",
        route_id=legacy_route.id,
        status=JourneyStatus.ACTIVE,
        when=now - timedelta(hours=1),
    )
    repository.add(fragmented)
    repository.add(legacy)
    fragments = (
        session.query(StoryFragmentModel)
        .join(StoryArcModel, StoryArcModel.id == StoryFragmentModel.arc_id)
        .filter(StoryArcModel.route_id == fragmented_route.id)
        .order_by(StoryFragmentModel.position)
        .all()
    )
    for index, fragment in enumerate(fragments):
        session.add(
            JourneyFragmentModel(
                id=f"aggregate-state-{index}",
                journey_id=fragmented.id,
                fragment_id=fragment.id,
                state="collected" if index < 2 else "undiscovered",
                playback_progress=1.0 if index < 2 else 0.0,
            )
        )
    first_stop = legacy_route.stops[0]
    session.add(
        JourneyAnswerModel(
            journey_id=legacy.id,
            stop_id=first_stop.id,
            selected_option=0,
            is_correct=True,
            answered_at=now,
        )
    )
    mission = (
        session.query(PhotoMissionModel)
        .join(StoryFragmentModel, StoryFragmentModel.id == PhotoMissionModel.fragment_id)
        .join(StoryArcModel, StoryArcModel.id == StoryFragmentModel.arc_id)
        .filter(StoryArcModel.route_id == fragmented_route.id)
        .first()
    )
    session.flush()
    session.add(
        EvidenceModel(
            id="aggregate-evidence",
            journey_id=fragmented.id,
            mission_id=mission.id,
            object_key="private/aggregate.jpg",
            storage_provider="local",
            canonical_reference=None,
            mime_type="image/jpeg",
            size_bytes=10,
            sha256="abc",
            width=10,
            height=10,
            captured_at=now,
            uploaded_at=now,
            expires_at=now + timedelta(days=30),
            deleted_at=None,
            idempotency_key="aggregate-retry",
        )
    )
    session.commit()

    items = repository.list_library_items("aggregate-owner")
    fragmented_item, legacy_item = items
    assert fragmented_item.route.content_status.value == "archived"
    assert fragmented_item.journey_kind == "fragmented"
    assert fragmented_item.collected_count == 2
    assert fragmented_item.total_count == len(fragments)
    assert fragmented_item.evidence_count == 1
    assert legacy_item.journey_kind == "legacy"
    assert legacy_item.collected_count == 1
    assert legacy_item.total_count == len(legacy_route.stops)
    assert legacy_item.evidence_count == 0
    session.close()
