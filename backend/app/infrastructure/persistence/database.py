from __future__ import annotations

from collections.abc import Callable

from sqlalchemy import Engine, create_engine, event
from sqlalchemy.orm import Session, scoped_session, sessionmaker

from app.infrastructure.persistence.models import Base


class Database:
    def __init__(self, database_url: str):
        connect_args = {"check_same_thread": False} if database_url.startswith("sqlite") else {}
        self.engine: Engine = create_engine(
            database_url,
            pool_pre_ping=True,
            connect_args=connect_args,
        )
        if database_url.startswith("sqlite"):
            event.listen(self.engine, "connect", self._enable_sqlite_foreign_keys)
        self.session_factory: Callable[[], Session] = scoped_session(
            sessionmaker(bind=self.engine, autoflush=False, expire_on_commit=False)
        )

    @staticmethod
    def _enable_sqlite_foreign_keys(connection: object, _: object) -> None:
        cursor = connection.cursor()
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.close()

    def create_all(self) -> None:
        Base.metadata.create_all(self.engine)

    def remove_session(self) -> None:
        remove = getattr(self.session_factory, "remove", None)
        if remove:
            remove()
