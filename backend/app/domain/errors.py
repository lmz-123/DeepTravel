from __future__ import annotations

from typing import Any


class DomainError(Exception):
    code = "domain_error"
    status_code = 400
    default_message = "请求无法处理"

    def __init__(self, message: str | None = None, details: dict[str, Any] | None = None):
        super().__init__(message or self.default_message)
        self.message = message or self.default_message
        self.details = details or {}


class NotFoundError(DomainError):
    code = "not_found"
    status_code = 404
    default_message = "资源不存在"


class UnauthorizedError(DomainError):
    code = "unauthorized"
    status_code = 401
    default_message = "请先创建游客会话"


class ValidationError(DomainError):
    code = "validation_error"
    status_code = 422
    default_message = "请求参数无效"


class JourneyConflictError(DomainError):
    code = "journey_state_conflict"
    status_code = 409
    default_message = "当前旅程状态不允许此操作"


class TooFarFromStopError(DomainError):
    code = "too_far_from_stop"
    status_code = 409
    default_message = "你还没有到达当前站点"


class DemoArrivalDisabledError(DomainError):
    code = "demo_arrival_disabled"
    status_code = 403
    default_message = "当前环境未启用演示到达"


class CityNotFoundError(NotFoundError):
    code = "city_not_found"
    default_message = "城市不存在"


class RouteNotFoundError(NotFoundError):
    code = "route_not_found"
    default_message = "路线不存在"


class JourneyNotFoundError(NotFoundError):
    code = "journey_not_found"
    default_message = "旅程不存在"


class FragmentOperationError(DomainError):
    def __init__(
        self,
        code: str,
        message: str,
        *,
        status_code: int = 409,
        details: dict[str, Any] | None = None,
    ):
        super().__init__(message, details)
        self.code = code
        self.status_code = status_code
