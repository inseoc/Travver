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
    ModifyDayRequest,
    PhotoDecorateRequest,
    VideoCreateRequest,
)
from .responses import (
    TravelPlanResponse,
    ModifyDayResponse,
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
    "ModifyDayRequest",
    "PhotoDecorateRequest",
    "VideoCreateRequest",
    # Response models
    "TravelPlanResponse",
    "ModifyDayResponse",
    "PhotoDecorateResponse",
    "VideoCreateResponse",
    "ErrorResponse",
    "HealthResponse",
]
