"""Shared API error shape. Endpoints return results instead of raising, so domain
errors reach clients as stable codes rather than HTTP 500s."""

import from domain.errors { DomainError }
import from api.contracts { ApiError }

def to_api_error(e: DomainError) -> ApiError {
    return ApiError(code=e.code, message=e.message);
}
