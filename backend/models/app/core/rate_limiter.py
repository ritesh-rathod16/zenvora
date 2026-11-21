import os
import logging
from fastapi import Request
from slowapi import Limiter
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded
from fastapi.responses import JSONResponse

logger = logging.getLogger(__name__)

def get_client_identifier(request: Request) -> str:
    """
    Extract client identifier safely.
    Prefers authenticated user ID or fallback to remote IP.
    Uses the direct peer address; forwarded headers are untrusted unless a trusted
    proxy is explicitly configured.
    """
    if hasattr(request.state, "user_id") and request.state.user_id:
        return f"user:{request.state.user_id}"

    return f"ip:{get_remote_address(request)}"

def _initialize_limiter() -> Limiter:
    """
    Initialize SlowAPI Limiter with Redis if available and reachable,
    otherwise fallback to memory:// storage for local development.
    """
    redis_url = os.getenv("REDIS_URL")
    if redis_url and redis_url != "memory://":
        try:
            import redis
            r = redis.from_url(redis_url, socket_timeout=0.2, connect_timeout=0.2)
            r.ping()
            logger.info("Redis rate limiter storage is available.")
            return Limiter(
                key_func=get_client_identifier,
                storage_uri=redis_url,
                strategy="moving-window"
            )
        except Exception:
            logger.info("Local Redis server not detected. Using in-memory rate limiting (memory://).")

    logger.info("Initializing Slowapi Limiter with in-memory storage backend (memory://).")
    return Limiter(
        key_func=get_client_identifier,
        storage_uri="memory://",
        strategy="moving-window"
    )

limiter = _initialize_limiter()

def rate_limit_exceeded_handler(request: Request, exc: RateLimitExceeded) -> JSONResponse:
    logger.warning("Rate limit exceeded.")
    response = JSONResponse(
        status_code=429,
        content={
            "detail": "Rate limit exceeded. Please try again later.",
            "error": "too_many_requests"
        }
    )
    response.headers["Retry-After"] = "60"
    return response
