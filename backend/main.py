"""Travver Backend - FastAPI Application."""

import time
from contextlib import asynccontextmanager
from typing import Any, Dict

from fastapi import FastAPI, HTTPException, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from core.config import settings
from core.logger import logger
from core.exceptions import TravverException, ValidationException, AIServiceException
from routes import agent_router, travel_router, memories_router
from database import db


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan handler."""
    # Startup
    logger.info("=" * 50)
    logger.info("Starting Travver Backend")
    logger.info(f"Environment: {settings.environment}")
    logger.info(f"Debug mode: {settings.debug}")
    logger.info("=" * 50)

    # Log API availability
    if settings.openai_api_key:
        logger.info("✓ OpenAI API configured")
    else:
        logger.warning("✗ OpenAI API not configured - using fallback mode")

    if settings.effective_gemini_api_key:
        logger.info("✓ Gemini API configured")
    else:
        logger.warning("✗ Gemini API not configured - using fallback mode")

    if settings.google_places_api_key:
        logger.info("✓ Google Places API configured")
    else:
        logger.warning("✗ Google Places API not configured - using mock data")

    # Initialize SQLite database
    await db.connect()
    logger.info("✓ SQLite database initialized")

    yield

    # Shutdown
    await db.disconnect()
    logger.info("Shutting down Travver Backend")


# Create FastAPI application
app = FastAPI(
    title=settings.app_name,
    description="""
## Travver - AI 기반 스마트 여행 플래너 API

### 주요 기능
- 🤖 **AI 여행 일정 생성**: Travel Planner Agent
- 💬 **AI 여행 컨설턴트**: Travel Consultant Agent
- 📸 **추억 남기기**: AI 사진 꾸미기 & 영상 생성
- 📋 **여행 관리**: CRUD 기능

### API 그룹
- `/agent`: AI Agent 관련 API
- `/travel`: 여행 CRUD API
- `/memories`: 사진/영상 API

### 인증
현재 버전은 인증이 구현되어 있지 않습니다.
향후 JWT 기반 인증이 추가될 예정입니다.
    """,
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
    lifespan=lifespan,
)

# CORS middleware - Flutter 앱에서 접근 가능하도록 설정
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# Request logging middleware
@app.middleware("http")
async def log_requests(request: Request, call_next):
    """Log all requests with timing."""
    start_time = time.time()

    # Log request
    logger.debug(f"Request: {request.method} {request.url.path}")

    response = await call_next(request)

    # Calculate duration
    duration = time.time() - start_time
    duration_ms = round(duration * 1000, 2)

    # Log response
    logger.debug(
        f"Response: {request.method} {request.url.path} "
        f"status={response.status_code} duration={duration_ms}ms"
    )

    # Add custom header
    response.headers["X-Response-Time"] = f"{duration_ms}ms"

    return response


# Exception handlers
@app.exception_handler(TravverException)
async def travver_exception_handler(request: Request, exc: TravverException):
    """Handle custom Travver exceptions."""
    logger.error(f"TravverException: {exc.code} - {exc.message}")
    return JSONResponse(
        status_code=status.HTTP_400_BAD_REQUEST,
        content={"error": exc.code, "message": exc.message},
    )


@app.exception_handler(ValidationException)
async def validation_exception_handler(request: Request, exc: ValidationException):
    """Handle validation exceptions."""
    logger.warning(f"ValidationException: {exc.code} - {exc.message}")
    return JSONResponse(
        status_code=status.HTTP_400_BAD_REQUEST,
        content={"error": exc.code, "message": exc.message},
    )


@app.exception_handler(AIServiceException)
async def ai_service_exception_handler(request: Request, exc: AIServiceException):
    """Handle AI service exceptions."""
    logger.error(f"AIServiceException: {exc.code} - {exc.message}")
    return JSONResponse(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        content={
            "error": exc.code,
            "message": "AI 서비스 오류가 발생했습니다. 잠시 후 다시 시도해주세요.",
        },
    )


@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    """Handle HTTP exceptions."""
    return JSONResponse(
        status_code=exc.status_code,
        content=exc.detail if isinstance(exc.detail, dict) else {"message": exc.detail},
    )


@app.exception_handler(Exception)
async def general_exception_handler(request: Request, exc: Exception):
    """Handle all other exceptions."""
    logger.exception(f"Unhandled exception: {exc}")
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={
            "error": "INTERNAL_ERROR",
            "message": "서버 오류가 발생했습니다.",
        },
    )


# Include routers
app.include_router(agent_router, prefix="/api/v1")
app.include_router(travel_router, prefix="/api/v1")
app.include_router(memories_router, prefix="/api/v1")


# Health check endpoints
@app.get("/", tags=["Health"])
async def root() -> Dict[str, str]:
    """Root endpoint."""
    return {
        "app": settings.app_name,
        "version": "1.0.0",
        "status": "running",
    }


@app.get("/health", tags=["Health"])
async def health_check() -> Dict[str, Any]:
    """Health check endpoint."""
    return {
        "status": "healthy",
        "environment": settings.environment,
        "services": {
            "openai": "configured" if settings.openai_api_key else "not_configured",
            "gemini": "configured" if settings.effective_gemini_api_key else "not_configured",
            "places": "configured" if settings.google_places_api_key else "not_configured",
            "database": "connected" if db._connection else "disconnected",
        },
    }


@app.get("/api/v1/status", tags=["Health"])
async def api_status() -> Dict[str, Any]:
    """API status endpoint with detailed information."""
    return {
        "api_version": "v1",
        "status": "operational",
        "endpoints": {
            "agent": {
                "travel_plan": "/api/v1/agent/travel-plan",
                "consultant": "/api/v1/agent/consultant",
                "consultant_stream": "/api/v1/agent/consultant/stream",
            },
            "travel": {
                "trips": "/api/v1/travel/trips",
                "trip_detail": "/api/v1/travel/trips/{trip_id}",
            },
            "memories": {
                "photo": "/api/v1/memories/photo",
                "video": "/api/v1/memories/video",
                "photo_styles": "/api/v1/memories/styles/photo",
                "video_styles": "/api/v1/memories/styles/video",
            },
        },
    }


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=settings.debug,
        log_level="debug" if settings.debug else "info",
    )
