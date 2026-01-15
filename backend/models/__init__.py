"""Pydantic models for API request/response."""

from .travel import (
    Location,
    Schedule,
    DailyPlan,
    TripPeriod,
    Budget,
    Trip,
    TravelStyle,
    PlaceCategory,
    TripStatus,
)
from .requests import (
    TravelPlanRequest,
    ConsultantRequest,
    PhotoDecorateRequest,
    VideoCreateRequest,
)
from .responses import (
    TravelPlanResponse,
    ConsultantResponse,
    PhotoDecorateResponse,
    VideoCreateResponse,
    ErrorResponse,
    HealthResponse,
)

__all__ = [
    # Travel models
    "Location",
    "Schedule",
    "DailyPlan",
    "TripPeriod",
    "Budget",
    "Trip",
    "TravelStyle",
    "PlaceCategory",
    "TripStatus",
    # Request models
    "TravelPlanRequest",
    "ConsultantRequest",
    "PhotoDecorateRequest",
    "VideoCreateRequest",
    # Response models
    "TravelPlanResponse",
    "ConsultantResponse",
    "PhotoDecorateResponse",
    "VideoCreateResponse",
    "ErrorResponse",
    "HealthResponse",
]
