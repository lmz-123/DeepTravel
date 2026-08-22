from __future__ import annotations

import base64
import hashlib
import hmac
import json
from datetime import UTC, datetime
from uuid import uuid4

from sqlalchemy import and_, exists, func, or_, select, update
from sqlalchemy.exc import IntegrityError

from app.domain.errors import FragmentOperationError, JourneyNotFoundError, ValidationError
from app.infrastructure.persistence.models import (
    CommunityCommentModel,
    CommunityMediaModel,
    CommunityPostLikeModel,
    CommunityPostModel,
    CommunityReportModel,
    EvidenceModel,
    JourneyFragmentModel,
    JourneyModel,
    PhotoMissionModel,
    UserModel,
)


def _iso(value: datetime | None) -> str | None:
    return value.isoformat() if value else None


class CommunityService:
    def __init__(
        self,
        session_factory,
        media_storage,
        evidence_storage,
        *,
        enabled: bool,
        secret_key: str,
        categories: tuple[str, ...],
        report_reasons: tuple[str, ...],
        title_max: int,
        body_max: int,
        comment_max: int,
        max_media: int,
        report_threshold: int,
    ):
        self.session_factory = session_factory
        self.media_storage = media_storage
        self.evidence_storage = evidence_storage
        self.enabled = enabled
        self.secret_key = secret_key.encode()
        self.categories = categories
        self.report_reasons = report_reasons
        self.title_max = title_max
        self.body_max = body_max
        self.comment_max = comment_max
        self.max_media = max_media
        self.report_threshold = max(1, report_threshold)

    def policy(self) -> dict:
        return {
            "enabled": self.enabled,
            "categories": [
                {"id": value, "label": self._category_label(value)} for value in self.categories
            ],
            "title_max_length": self.title_max,
            "body_max_length": self.body_max,
            "comment_max_length": self.comment_max,
            "max_media": self.max_media,
            "allowed_mime_types": sorted(self.media_storage.accepted_mime_types),
            "report_reasons": list(self.report_reasons),
            "private_source_remains_private": True,
            "community_copy_is_independent": True,
            "traveler_content_is_unverified": True,
        }

    def feed(
        self,
        user_id: str,
        journey_id: str,
        fragment_id: str,
        *,
        category: str | None,
        cursor: str | None,
        limit: int,
    ) -> dict:
        self._require_enabled()
        if category is not None and category not in self.categories:
            raise ValidationError("category 不受支持")
        limit = self._limit(limit)
        scope = f"posts:{fragment_id}:{category or 'all'}"
        boundary = self._decode_cursor(cursor, scope) if cursor else None
        with self.session_factory() as session:
            self._authorize_journey_fragment(session, user_id, journey_id, fragment_id)
            hidden = self._reported_exists(user_id, "post", CommunityPostModel.id)
            query = select(CommunityPostModel).where(
                CommunityPostModel.fragment_id == fragment_id,
                CommunityPostModel.status == "visible",
                ~hidden,
            )
            if category:
                query = query.where(CommunityPostModel.category == category)
            if boundary:
                created_at, item_id = boundary
                query = query.where(
                    or_(
                        CommunityPostModel.created_at < created_at,
                        and_(
                            CommunityPostModel.created_at == created_at,
                            CommunityPostModel.id < item_id,
                        ),
                    )
                )
            rows = list(
                session.scalars(
                    query.order_by(
                        CommunityPostModel.created_at.desc(), CommunityPostModel.id.desc()
                    ).limit(limit + 1)
                )
            )
            has_more = len(rows) > limit
            rows = rows[:limit]
            items = self._post_payloads(session, rows, user_id, summary=True)
            next_cursor = None
            if has_more and rows:
                last = rows[-1]
                next_cursor = self._encode_cursor(scope, last.created_at, last.id)
            return {"items": items, "next_cursor": next_cursor}

    def create_post(
        self,
        user_id: str,
        journey_id: str,
        fragment_id: str,
        *,
        category: str,
        title: str | None,
        body: str | None,
        idempotency_key: str,
        files: list,
        evidence_ids: list[str],
    ) -> dict:
        self._require_enabled()
        title = (title or "").strip() or None
        body = (body or "").strip()
        if category not in self.categories:
            raise ValidationError("category 不受支持")
        if not idempotency_key or len(idempotency_key) > 80:
            raise ValidationError("idempotency_key 为必填字段且不得超过 80 字符")
        if title and len(title) > self.title_max:
            raise ValidationError(f"标题不得超过 {self.title_max} 字")
        if len(body) > self.body_max:
            raise ValidationError(f"正文不得超过 {self.body_max} 字")
        if len(files) + len(evidence_ids) > self.max_media:
            raise ValidationError(f"每条动态最多 {self.max_media} 张图片")
        if not title and not body and not files and not evidence_ids:
            raise ValidationError("动态需要标题、文字或图片")

        staged: list[tuple[object, str]] = []
        with self.session_factory() as session:
            self._authorize_journey_fragment(session, user_id, journey_id, fragment_id)
            duplicate = session.scalar(
                select(CommunityPostModel).where(
                    CommunityPostModel.author_user_id == user_id,
                    CommunityPostModel.idempotency_key == idempotency_key,
                )
            )
            if duplicate is not None:
                if duplicate.fragment_id != fragment_id:
                    raise ValidationError("idempotency_key 已用于另一条动态")
                return self._post_payloads(session, [duplicate], user_id, summary=False)[0]

            post_id = str(uuid4())
            try:
                for file in files:
                    stored = self.media_storage.put(
                        file.stream,
                        file.mimetype or "application/octet-stream",
                        scope=f"{fragment_id}/{post_id}",
                    )
                    staged.append((stored, "upload"))
                for evidence_id in evidence_ids:
                    now = datetime.now(UTC)
                    evidence = session.scalar(
                        select(EvidenceModel)
                        .join(JourneyModel, JourneyModel.id == EvidenceModel.journey_id)
                        .join(PhotoMissionModel, PhotoMissionModel.id == EvidenceModel.mission_id)
                        .where(
                            EvidenceModel.id == evidence_id,
                            EvidenceModel.deleted_at.is_(None),
                            EvidenceModel.expires_at > now,
                            JourneyModel.id == journey_id,
                            JourneyModel.user_id == user_id,
                            PhotoMissionModel.fragment_id == fragment_id,
                        )
                    )
                    if evidence is None:
                        raise FragmentOperationError(
                            "community_source_not_found", "足迹照片不存在", status_code=404
                        )
                    stored = self.media_storage.put(
                        self.evidence_storage.open(evidence.object_key),
                        evidence.mime_type,
                        scope=f"{fragment_id}/{post_id}",
                    )
                    staged.append((stored, "evidence_copy"))

                now = datetime.now(UTC)
                post = CommunityPostModel(
                    id=post_id,
                    fragment_id=fragment_id,
                    author_user_id=user_id,
                    category=category,
                    title=title,
                    body=body,
                    status="visible",
                    report_count=0,
                    idempotency_key=idempotency_key,
                    created_at=now,
                    updated_at=now,
                )
                session.add(post)
                session.flush()
                for position, (stored, source_kind) in enumerate(staged):
                    session.add(
                        CommunityMediaModel(
                            id=str(uuid4()),
                            post_id=post_id,
                            position=position,
                            storage_provider=self.media_storage.provider,
                            object_key=stored.object_key,
                            canonical_reference=self.media_storage.canonical_reference(
                                stored.object_key
                            ),
                            mime_type=stored.mime_type,
                            size_bytes=stored.size_bytes,
                            sha256=stored.sha256,
                            width=stored.width,
                            height=stored.height,
                            source_kind=source_kind,
                            created_at=now,
                        )
                    )
                session.commit()
                return self._post_payloads(session, [post], user_id, summary=False)[0]
            except IntegrityError:
                session.rollback()
                for stored, _ in staged:
                    try:
                        self.media_storage.delete(stored.object_key)
                    except Exception:
                        pass
                duplicate = session.scalar(
                    select(CommunityPostModel).where(
                        CommunityPostModel.author_user_id == user_id,
                        CommunityPostModel.idempotency_key == idempotency_key,
                        CommunityPostModel.fragment_id == fragment_id,
                    )
                )
                if duplicate is not None:
                    return self._post_payloads(session, [duplicate], user_id, summary=False)[0]
                raise
            except Exception:
                session.rollback()
                for stored, _ in staged:
                    try:
                        self.media_storage.delete(stored.object_key)
                    except Exception:
                        pass
                raise

    def detail(self, user_id: str, post_id: str) -> dict:
        self._require_enabled()
        with self.session_factory() as session:
            post = self._visible_post(session, user_id, post_id)
            return self._post_payloads(session, [post], user_id, summary=False)[0]

    def likers(self, user_id: str, post_id: str, *, cursor: str | None, limit: int) -> dict:
        self._require_enabled()
        limit = self._limit(limit)
        scope = f"likes:{post_id}"
        boundary = self._decode_cursor(cursor, scope) if cursor else None
        with self.session_factory() as session:
            self._visible_post(session, user_id, post_id)
            query = (
                select(CommunityPostLikeModel, UserModel)
                .join(UserModel, UserModel.id == CommunityPostLikeModel.user_id)
                .where(CommunityPostLikeModel.post_id == post_id)
            )
            if boundary:
                created_at, item_id = boundary
                query = query.where(
                    or_(
                        CommunityPostLikeModel.created_at < created_at,
                        and_(
                            CommunityPostLikeModel.created_at == created_at,
                            CommunityPostLikeModel.id < item_id,
                        ),
                    )
                )
            rows = session.execute(
                query.order_by(
                    CommunityPostLikeModel.created_at.desc(),
                    CommunityPostLikeModel.id.desc(),
                ).limit(limit + 1)
            ).all()
            has_more = len(rows) > limit
            rows = rows[:limit]
            items = [self._author_payload(user) for _, user in rows]
            next_cursor = None
            if has_more and rows:
                like = rows[-1][0]
                next_cursor = self._encode_cursor(scope, like.created_at, like.id)
            return {"items": items, "next_cursor": next_cursor}

    def set_like(self, user_id: str, post_id: str, liked: bool) -> dict:
        self._require_enabled()
        with self.session_factory() as session:
            self._visible_post(session, user_id, post_id)
            existing = session.scalar(
                select(CommunityPostLikeModel).where(
                    CommunityPostLikeModel.post_id == post_id,
                    CommunityPostLikeModel.user_id == user_id,
                )
            )
            if liked and existing is None:
                session.add(
                    CommunityPostLikeModel(
                        id=str(uuid4()),
                        post_id=post_id,
                        user_id=user_id,
                        created_at=datetime.now(UTC),
                    )
                )
            elif not liked and existing is not None:
                session.delete(existing)
            try:
                session.commit()
            except IntegrityError:
                session.rollback()
            count = session.scalar(
                select(func.count())
                .select_from(CommunityPostLikeModel)
                .where(CommunityPostLikeModel.post_id == post_id)
            )
            return {"post_id": post_id, "viewer_has_liked": liked, "like_count": count}

    def comments(self, user_id: str, post_id: str, *, cursor: str | None, limit: int) -> dict:
        self._require_enabled()
        limit = self._limit(limit)
        scope = f"comments:{post_id}"
        boundary = self._decode_cursor(cursor, scope) if cursor else None
        with self.session_factory() as session:
            self._visible_post(session, user_id, post_id)
            hidden = self._reported_exists(user_id, "comment", CommunityCommentModel.id)
            # Use an explicit reply alias so the correlated EXISTS remains
            # unambiguous on both SQLite and MySQL.
            from sqlalchemy.orm import aliased

            reply = aliased(CommunityCommentModel)
            visible_reply_exists = exists(
                select(reply.id).where(
                    reply.root_comment_id == CommunityCommentModel.id,
                    reply.status == "visible",
                    ~self._reported_exists(user_id, "comment", reply.id),
                )
            )
            query = (
                select(CommunityCommentModel, UserModel)
                .join(UserModel, UserModel.id == CommunityCommentModel.author_user_id)
                .where(
                    CommunityCommentModel.post_id == post_id,
                    CommunityCommentModel.root_comment_id.is_(None),
                    or_(
                        and_(CommunityCommentModel.status == "visible", ~hidden),
                        visible_reply_exists,
                    ),
                )
            )
            if boundary:
                created_at, item_id = boundary
                query = query.where(
                    or_(
                        CommunityCommentModel.created_at > created_at,
                        and_(
                            CommunityCommentModel.created_at == created_at,
                            CommunityCommentModel.id > item_id,
                        ),
                    )
                )
            rows = session.execute(
                query.order_by(
                    CommunityCommentModel.created_at.asc(), CommunityCommentModel.id.asc()
                ).limit(limit + 1)
            ).all()
            has_more = len(rows) > limit
            rows = rows[:limit]
            items = self._thread_payloads(session, rows, user_id)
            next_cursor = None
            if has_more and rows:
                comment = rows[-1][0]
                next_cursor = self._encode_cursor(scope, comment.created_at, comment.id)
            return {"items": items, "next_cursor": next_cursor}

    def replies(
        self, user_id: str, root_comment_id: str, *, cursor: str | None, limit: int
    ) -> dict:
        self._require_enabled()
        limit = self._limit(limit)
        scope = f"replies:{root_comment_id}"
        boundary = self._decode_cursor(cursor, scope) if cursor else None
        with self.session_factory() as session:
            root = session.get(CommunityCommentModel, root_comment_id)
            if root is None or root.root_comment_id is not None:
                raise FragmentOperationError(
                    "community_comment_not_found", "评论不存在", status_code=404
                )
            self._visible_post(session, user_id, root.post_id)
            hidden = self._reported_exists(user_id, "comment", CommunityCommentModel.id)
            query = (
                select(CommunityCommentModel, UserModel)
                .join(UserModel, UserModel.id == CommunityCommentModel.author_user_id)
                .where(
                    CommunityCommentModel.root_comment_id == root_comment_id,
                    CommunityCommentModel.status == "visible",
                    ~hidden,
                )
            )
            if boundary:
                created_at, item_id = boundary
                query = query.where(
                    or_(
                        CommunityCommentModel.created_at > created_at,
                        and_(
                            CommunityCommentModel.created_at == created_at,
                            CommunityCommentModel.id > item_id,
                        ),
                    )
                )
            rows = session.execute(
                query.order_by(
                    CommunityCommentModel.created_at.asc(), CommunityCommentModel.id.asc()
                ).limit(limit + 1)
            ).all()
            has_more = len(rows) > limit
            rows = rows[:limit]
            target_ids = {item.reply_to_comment_id for item, _ in rows if item.reply_to_comment_id}
            target_author_ids = set(
                session.scalars(
                    select(CommunityCommentModel.author_user_id).where(
                        CommunityCommentModel.id.in_(target_ids)
                    )
                )
            )
            target_authors = {
                item.id: item
                for item in session.scalars(
                    select(UserModel).where(UserModel.id.in_(target_author_ids))
                )
            }
            target_author_by_comment = {
                item.id: target_authors.get(item.author_user_id)
                for item in session.scalars(
                    select(CommunityCommentModel).where(CommunityCommentModel.id.in_(target_ids))
                )
            }
            items = [
                self._comment_payload(
                    comment,
                    author,
                    user_id,
                    reply_to_author=target_author_by_comment.get(comment.reply_to_comment_id),
                )
                for comment, author in rows
            ]
            next_cursor = None
            if has_more and rows:
                last = rows[-1][0]
                next_cursor = self._encode_cursor(scope, last.created_at, last.id)
            return {"items": items, "next_cursor": next_cursor}

    def create_comment(
        self,
        user_id: str,
        post_id: str,
        *,
        body: str,
        idempotency_key: str,
        reply_to_comment_id: str | None = None,
    ) -> dict:
        self._require_enabled()
        body = body.strip()
        if not body or len(body) > self.comment_max:
            raise ValidationError(f"评论需为 1–{self.comment_max} 字")
        if not idempotency_key or len(idempotency_key) > 80:
            raise ValidationError("idempotency_key 为必填字段且不得超过 80 字符")
        with self.session_factory() as session:
            self._visible_post(session, user_id, post_id)
            root_comment_id = None
            reply_to = None
            if reply_to_comment_id:
                reply_to = session.get(CommunityCommentModel, reply_to_comment_id)
                reported = session.scalar(
                    select(CommunityReportModel.id).where(
                        CommunityReportModel.reporter_user_id == user_id,
                        CommunityReportModel.target_type == "comment",
                        CommunityReportModel.target_id == reply_to_comment_id,
                    )
                )
                if (
                    reply_to is None
                    or reply_to.post_id != post_id
                    or reply_to.status != "visible"
                    or reported is not None
                ):
                    raise FragmentOperationError(
                        "community_comment_not_found", "评论不存在", status_code=404
                    )
                root = (
                    reply_to
                    if reply_to.root_comment_id is None
                    else session.get(CommunityCommentModel, reply_to.root_comment_id)
                )
                if root is None or root.post_id != post_id:
                    raise FragmentOperationError(
                        "community_comment_not_found", "评论不存在", status_code=404
                    )
                root_comment_id = root.id
            duplicate = session.scalar(
                select(CommunityCommentModel).where(
                    CommunityCommentModel.author_user_id == user_id,
                    CommunityCommentModel.idempotency_key == idempotency_key,
                )
            )
            if duplicate:
                if duplicate.post_id != post_id:
                    raise ValidationError("idempotency_key 已用于另一条评论")
                author = session.get(UserModel, user_id)
                target_author = None
                if duplicate.reply_to_comment_id:
                    target = session.get(CommunityCommentModel, duplicate.reply_to_comment_id)
                    target_author = (
                        session.get(UserModel, target.author_user_id) if target else None
                    )
                return self._comment_payload(
                    duplicate, author, user_id, reply_to_author=target_author
                )
            now = datetime.now(UTC)
            comment = CommunityCommentModel(
                id=str(uuid4()),
                post_id=post_id,
                root_comment_id=root_comment_id,
                reply_to_comment_id=reply_to_comment_id or None,
                author_user_id=user_id,
                body=body,
                status="visible",
                report_count=0,
                idempotency_key=idempotency_key,
                created_at=now,
                updated_at=now,
            )
            session.add(comment)
            try:
                session.commit()
            except IntegrityError:
                session.rollback()
                duplicate = session.scalar(
                    select(CommunityCommentModel).where(
                        CommunityCommentModel.author_user_id == user_id,
                        CommunityCommentModel.idempotency_key == idempotency_key,
                        CommunityCommentModel.post_id == post_id,
                    )
                )
                if duplicate is None:
                    raise
                comment = duplicate
            author = session.get(UserModel, user_id)
            reply_to_author = (
                session.get(UserModel, reply_to.author_user_id) if reply_to is not None else None
            )
            return self._comment_payload(
                comment, author, user_id, reply_to_author=reply_to_author
            )

    def delete_post(self, user_id: str, post_id: str) -> dict:
        self._require_enabled()
        keys: list[str] = []
        with self.session_factory() as session:
            post = session.get(CommunityPostModel, post_id)
            if post is None or post.status != "visible":
                raise FragmentOperationError(
                    "community_post_not_found", "动态不存在", status_code=404
                )
            self._authorize_fragment(session, user_id, post.fragment_id)
            if post.author_user_id != user_id:
                raise FragmentOperationError(
                    "community_forbidden", "只能删除自己的动态", status_code=403
                )
            now = datetime.now(UTC)
            post.status = "deleted"
            post.deleted_at = now
            post.updated_at = now
            keys = list(
                session.scalars(
                    select(CommunityMediaModel.object_key).where(
                        CommunityMediaModel.post_id == post_id
                    )
                )
            )
            session.commit()
        for key in keys:
            try:
                self.media_storage.delete(key)
            except Exception:
                pass
        return {"id": post_id, "deleted": True}

    def delete_comment(self, user_id: str, comment_id: str) -> dict:
        self._require_enabled()
        with self.session_factory() as session:
            comment = session.get(CommunityCommentModel, comment_id)
            if comment is None or comment.status != "visible":
                raise FragmentOperationError(
                    "community_comment_not_found", "评论不存在", status_code=404
                )
            post = session.get(CommunityPostModel, comment.post_id)
            self._authorize_fragment(session, user_id, post.fragment_id)
            if comment.author_user_id != user_id:
                raise FragmentOperationError(
                    "community_forbidden", "只能删除自己的评论", status_code=403
                )
            now = datetime.now(UTC)
            comment.status = "deleted"
            comment.deleted_at = now
            comment.updated_at = now
            session.commit()
            return {"id": comment_id, "deleted": True}

    def report(self, user_id: str, target_type: str, target_id: str, reason: str) -> dict:
        self._require_enabled()
        if target_type not in {"post", "comment"} or reason not in self.report_reasons:
            raise ValidationError("举报目标或原因不受支持")
        with self.session_factory() as session:
            if target_type == "post":
                target = self._visible_post(session, user_id, target_id)
                author_id = target.author_user_id
            else:
                target = session.get(CommunityCommentModel, target_id)
                if target is None or target.status != "visible":
                    raise FragmentOperationError(
                        "community_comment_not_found", "评论不存在", status_code=404
                    )
                post = self._visible_post(session, user_id, target.post_id)
                author_id = target.author_user_id
                self._authorize_fragment(session, user_id, post.fragment_id)
            if author_id == user_id:
                raise ValidationError("不能举报自己的内容")
            existing = session.scalar(
                select(CommunityReportModel).where(
                    CommunityReportModel.reporter_user_id == user_id,
                    CommunityReportModel.target_type == target_type,
                    CommunityReportModel.target_id == target_id,
                )
            )
            if existing is None:
                report = CommunityReportModel(
                    id=str(uuid4()),
                    reporter_user_id=user_id,
                    target_type=target_type,
                    target_id=target_id,
                    reason=reason,
                    created_at=datetime.now(UTC),
                )
                session.add(report)
                try:
                    session.flush()
                    target_model = (
                        CommunityPostModel if target_type == "post" else CommunityCommentModel
                    )
                    session.execute(
                        update(target_model)
                        .where(target_model.id == target_id)
                        .values(report_count=target_model.report_count + 1)
                    )
                    session.flush()
                    session.refresh(target)
                    if target.report_count >= self.report_threshold:
                        target.status = "held"
                    session.commit()
                except IntegrityError:
                    session.rollback()
            return {"target_type": target_type, "target_id": target_id, "reported": True}

    def open_media(self, user_id: str, media_id: str):
        self._require_enabled()
        with self.session_factory() as session:
            media = session.get(CommunityMediaModel, media_id)
            if media is None:
                raise FragmentOperationError(
                    "community_media_not_found", "图片不存在", status_code=404
                )
            self._visible_post(session, user_id, media.post_id)
            return self.media_storage.open(media.object_key), media.mime_type

    def _post_payloads(
        self, session, posts: list[CommunityPostModel], user_id: str, *, summary: bool
    ) -> list[dict]:
        if not posts:
            return []
        post_ids = [post.id for post in posts]
        author_ids = {post.author_user_id for post in posts}
        authors = {
            user.id: user
            for user in session.scalars(select(UserModel).where(UserModel.id.in_(author_ids)))
        }
        media_by_post: dict[str, list[CommunityMediaModel]] = {post_id: [] for post_id in post_ids}
        for media in session.scalars(
            select(CommunityMediaModel)
            .where(CommunityMediaModel.post_id.in_(post_ids))
            .order_by(CommunityMediaModel.post_id, CommunityMediaModel.position)
        ):
            media_by_post[media.post_id].append(media)
        like_counts = dict(
            session.execute(
                select(CommunityPostLikeModel.post_id, func.count())
                .where(CommunityPostLikeModel.post_id.in_(post_ids))
                .group_by(CommunityPostLikeModel.post_id)
            ).all()
        )
        hidden_comments = self._reported_exists(user_id, "comment", CommunityCommentModel.id)
        comment_counts = dict(
            session.execute(
                select(CommunityCommentModel.post_id, func.count())
                .where(
                    CommunityCommentModel.post_id.in_(post_ids),
                    CommunityCommentModel.status == "visible",
                    ~hidden_comments,
                )
                .group_by(CommunityCommentModel.post_id)
            ).all()
        )
        viewer_likes = set(
            session.scalars(
                select(CommunityPostLikeModel.post_id).where(
                    CommunityPostLikeModel.post_id.in_(post_ids),
                    CommunityPostLikeModel.user_id == user_id,
                )
            )
        )
        result = []
        for post in posts:
            body = post.body or ""
            item = {
                "id": post.id,
                "fragment_id": post.fragment_id,
                "category": post.category,
                "category_label": self._category_label(post.category),
                "traveler_content": True,
                "title": post.title,
                "body": body[:220] if summary and len(body) > 220 else body,
                "body_truncated": summary and len(body) > 220,
                "author": self._author_payload(authors[post.author_user_id]),
                "media": [self._media_payload(media) for media in media_by_post[post.id]],
                "like_count": int(like_counts.get(post.id, 0)),
                "comment_count": int(comment_counts.get(post.id, 0)),
                "viewer_has_liked": post.id in viewer_likes,
                "viewer_is_author": post.author_user_id == user_id,
                "created_at": _iso(post.created_at),
                "updated_at": _iso(post.updated_at),
            }
            result.append(item)
        return result

    @staticmethod
    def _author_payload(user: UserModel) -> dict:
        return {"display_name": (user.username or "见地旅行者"), "avatar": "default"}

    @staticmethod
    def _media_payload(media: CommunityMediaModel) -> dict:
        return {
            "id": media.id,
            "url": f"/api/v1/community-media/{media.id}",
            "mime_type": media.mime_type,
            "width": media.width,
            "height": media.height,
            "position": media.position,
        }

    def _comment_payload(
        self,
        comment,
        author,
        user_id: str,
        *,
        reply_to_author=None,
        reply_count: int = 0,
        reply_preview: list[dict] | None = None,
        tombstone: bool = False,
    ) -> dict:
        return {
            "id": comment.id,
            "post_id": comment.post_id,
            "root_comment_id": comment.root_comment_id,
            "reply_to_comment_id": comment.reply_to_comment_id,
            "body": "" if tombstone else comment.body,
            "author": None if tombstone else self._author_payload(author),
            "reply_to": (
                self._author_payload(reply_to_author) if reply_to_author is not None else None
            ),
            "viewer_is_author": not tombstone and comment.author_user_id == user_id,
            "is_tombstone": tombstone,
            "reply_count": reply_count,
            "reply_preview": reply_preview or [],
            "created_at": _iso(comment.created_at),
        }

    def _thread_payloads(self, session, rows, user_id: str) -> list[dict]:
        if not rows:
            return []
        roots = [comment for comment, _ in rows]
        root_ids = [comment.id for comment in roots]
        hidden_ids = set(
            session.scalars(
                select(CommunityReportModel.target_id).where(
                    CommunityReportModel.reporter_user_id == user_id,
                    CommunityReportModel.target_type == "comment",
                    CommunityReportModel.target_id.in_(root_ids),
                )
            )
        )
        hidden_reply = self._reported_exists(user_id, "comment", CommunityCommentModel.id)
        reply_counts = dict(
            session.execute(
                select(CommunityCommentModel.root_comment_id, func.count())
                .where(
                    CommunityCommentModel.root_comment_id.in_(root_ids),
                    CommunityCommentModel.status == "visible",
                    ~hidden_reply,
                )
                .group_by(CommunityCommentModel.root_comment_id)
            ).all()
        )
        ranked_replies = (
            select(
                CommunityCommentModel.id.label("comment_id"),
                func.row_number()
                .over(
                    partition_by=CommunityCommentModel.root_comment_id,
                    order_by=(
                        CommunityCommentModel.created_at.asc(),
                        CommunityCommentModel.id.asc(),
                    ),
                )
                .label("reply_rank"),
            )
            .where(
                CommunityCommentModel.root_comment_id.in_(root_ids),
                CommunityCommentModel.status == "visible",
                ~hidden_reply,
            )
            .subquery()
        )
        reply_rows = session.execute(
            select(CommunityCommentModel, UserModel)
            .join(UserModel, UserModel.id == CommunityCommentModel.author_user_id)
            .join(ranked_replies, ranked_replies.c.comment_id == CommunityCommentModel.id)
            .where(ranked_replies.c.reply_rank <= 2)
            .order_by(
                CommunityCommentModel.root_comment_id,
                CommunityCommentModel.created_at.asc(),
                CommunityCommentModel.id.asc(),
            )
        ).all()
        preview_rows: dict[str, list[tuple]] = {root_id: [] for root_id in root_ids}
        target_ids = set()
        for reply, author in reply_rows:
            root_id = reply.root_comment_id
            preview_rows[root_id].append((reply, author))
            if reply.reply_to_comment_id:
                target_ids.add(reply.reply_to_comment_id)
        targets = {
            item.id: item
            for item in session.scalars(
                select(CommunityCommentModel).where(CommunityCommentModel.id.in_(target_ids))
            )
        }
        target_authors = {
            item.id: item
            for item in session.scalars(
                select(UserModel).where(
                    UserModel.id.in_({target.author_user_id for target in targets.values()})
                )
            )
        }
        result = []
        for root, author in rows:
            previews = []
            for reply, reply_author in preview_rows[root.id]:
                target = targets.get(reply.reply_to_comment_id)
                previews.append(
                    self._comment_payload(
                        reply,
                        reply_author,
                        user_id,
                        reply_to_author=(
                            target_authors.get(target.author_user_id) if target else None
                        ),
                    )
                )
            result.append(
                self._comment_payload(
                    root,
                    author,
                    user_id,
                    reply_count=reply_counts.get(root.id, 0),
                    reply_preview=previews,
                    tombstone=root.status != "visible" or root.id in hidden_ids,
                )
            )
        return result

    def _visible_post(self, session, user_id: str, post_id: str) -> CommunityPostModel:
        post = session.get(CommunityPostModel, post_id)
        if post is None or post.status != "visible":
            raise FragmentOperationError("community_post_not_found", "动态不存在", status_code=404)
        reported = session.scalar(
            select(CommunityReportModel.id).where(
                CommunityReportModel.reporter_user_id == user_id,
                CommunityReportModel.target_type == "post",
                CommunityReportModel.target_id == post_id,
            )
        )
        if reported is not None:
            raise FragmentOperationError("community_post_not_found", "动态不存在", status_code=404)
        self._authorize_fragment(session, user_id, post.fragment_id)
        return post

    @staticmethod
    def _authorize_journey_fragment(session, user_id: str, journey_id: str, fragment_id: str):
        state = session.scalar(
            select(JourneyFragmentModel)
            .join(JourneyModel, JourneyModel.id == JourneyFragmentModel.journey_id)
            .where(
                JourneyModel.id == journey_id,
                JourneyModel.user_id == user_id,
                JourneyFragmentModel.fragment_id == fragment_id,
                JourneyFragmentModel.state != "undiscovered",
            )
        )
        if state is None:
            owned = session.scalar(
                select(JourneyModel.id).where(
                    JourneyModel.id == journey_id, JourneyModel.user_id == user_id
                )
            )
            if owned is None:
                raise JourneyNotFoundError()
            raise FragmentOperationError(
                "community_fragment_locked", "节点尚未解锁", status_code=404
            )
        return state

    @staticmethod
    def _authorize_fragment(session, user_id: str, fragment_id: str):
        state = session.scalar(
            select(JourneyFragmentModel)
            .join(JourneyModel, JourneyModel.id == JourneyFragmentModel.journey_id)
            .where(
                JourneyModel.user_id == user_id,
                JourneyFragmentModel.fragment_id == fragment_id,
                JourneyFragmentModel.state != "undiscovered",
            )
            .limit(1)
        )
        if state is None:
            raise FragmentOperationError(
                "community_fragment_locked", "节点尚未解锁", status_code=404
            )
        return state

    @staticmethod
    def _reported_exists(user_id: str, target_type: str, target_column):
        return exists(
            select(CommunityReportModel.id).where(
                CommunityReportModel.reporter_user_id == user_id,
                CommunityReportModel.target_type == target_type,
                CommunityReportModel.target_id == target_column,
            )
        )

    def _encode_cursor(self, scope: str, created_at: datetime, item_id: str) -> str:
        payload = json.dumps(
            {"scope": scope, "created_at": created_at.isoformat(), "id": item_id},
            separators=(",", ":"),
            sort_keys=True,
        ).encode()
        signature = hmac.new(self.secret_key, payload, hashlib.sha256).hexdigest().encode()
        return base64.urlsafe_b64encode(payload + b"." + signature).decode().rstrip("=")

    def _decode_cursor(self, cursor: str, scope: str) -> tuple[datetime, str]:
        try:
            padded = cursor + "=" * (-len(cursor) % 4)
            raw = base64.urlsafe_b64decode(padded.encode())
            payload, signature = raw.rsplit(b".", 1)
            expected = hmac.new(self.secret_key, payload, hashlib.sha256).hexdigest().encode()
            if not hmac.compare_digest(signature, expected):
                raise ValueError
            data = json.loads(payload)
            if data.get("scope") != scope:
                raise ValueError
            return datetime.fromisoformat(data["created_at"]), str(data["id"])
        except (ValueError, TypeError, KeyError, json.JSONDecodeError) as exc:
            raise ValidationError("cursor 无效或与当前筛选条件不匹配") from exc

    @staticmethod
    def _limit(limit: int) -> int:
        if isinstance(limit, bool) or limit < 1:
            raise ValidationError("limit 必须为正整数")
        return min(limit, 20)

    def _require_enabled(self) -> None:
        if not self.enabled:
            raise FragmentOperationError("community_disabled", "见地现场暂未开放", status_code=503)

    @staticmethod
    def _category_label(category: str) -> str:
        return {
            "viewpoint": "经典机位",
            "experience": "行走经验",
            "fact_supplement": "事实补充 · 旅行者内容",
            "on_site": "现场发现",
        }.get(category, category)
