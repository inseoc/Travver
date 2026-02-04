"""Travel-related Pydantic models."""

from datetime import date, datetime
from enum import Enum
from typing import List, Optional
from pydantic import BaseModel, Field, field_validator


class TravelStyle(str, Enum):
    """여행 스타일."""
    FOOD = "food"
    SIGHTSEEING = "sightseeing"
    RELAXATION = "relaxation"
    ACTIVITY = "activity"
    SHOPPING = "shopping"
    PHOTO = "photo"


class PlaceCategory(str, Enum):
    """장소 카테고리."""
    FOOD = "food"
    SIGHTSEEING = "sightseeing"
    ACCOMMODATION = "accommodation"
    ACTIVITY = "activity"
    SHOPPING = "shopping"
    TRANSPORT = "transport"
    REST = "rest"
    PHOTO = "photo"


class TripStatus(str, Enum):
    """여행 상태."""
    UPCOMING = "upcoming"
    ONGOING = "ongoing"
    COMPLETED = "completed"


class Location(BaseModel):
    """위치 좌표."""
    lat: float = Field(..., ge=-90, le=90, description="위도")
    lng: float = Field(..., ge=-180, le=180, description="경도")

    class Config:
        json_schema_extra = {
            "example": {"lat": 34.6687, "lng": 135.5065}
        }


class Schedule(BaseModel):
    """일정 항목."""
    order: int = Field(..., ge=1, description="방문 순서")
    time: str = Field(..., pattern=r"^\d{2}:\d{2}$", description="시작 시간 (HH:MM)")
    place: str = Field(..., min_length=1, max_length=200, description="장소명")
    category: PlaceCategory = Field(..., description="장소 카테고리")
    duration_min: int = Field(..., ge=15, le=480, description="소요 시간 (분)")
    estimated_cost: int = Field(default=0, ge=0, description="예상 비용 (KRW)")
    description: str = Field(default="", max_length=500, description="장소 설명")
    location: Location = Field(..., description="좌표")
    image_url: Optional[str] = Field(default=None, description="장소 이미지 URL")
    rating: Optional[float] = Field(default=None, ge=0, le=5, description="평점")
    place_id: Optional[str] = Field(default=None, description="Google Places ID")

    class Config:
        json_schema_extra = {
            "example": {
                "order": 1,
                "time": "10:00",
                "place": "구로몬 시장",
                "category": "food",
                "duration_min": 90,
                "estimated_cost": 15000,
                "description": "오사카의 부엌, 신선한 해산물 아침 식사",
                "location": {"lat": 34.6687, "lng": 135.5065}
            }
        }


class DailyPlan(BaseModel):
    """일일 계획."""
    day: int = Field(..., ge=1, description="여행 일차")
    plan_date: date = Field(..., description="날짜", alias="date")
    theme: str = Field(default="", max_length=100, description="당일 테마")
    schedules: List[Schedule] = Field(default_factory=list, description="일정 목록")

    model_config = {"populate_by_name": True}

    @property
    def total_cost(self) -> int:
        """당일 총 예상 비용."""
        return sum(s.estimated_cost for s in self.schedules)

    @property
    def total_duration(self) -> int:
        """당일 총 소요 시간 (분)."""
        return sum(s.duration_min for s in self.schedules)


class TripPeriod(BaseModel):
    """여행 기간."""
    start: date = Field(..., description="시작일")
    end: date = Field(..., description="종료일")

    @field_validator("end")
    @classmethod
    def end_after_start(cls, v: date, info) -> date:
        """종료일이 시작일 이후인지 검증."""
        if "start" in info.data and v < info.data["start"]:
            raise ValueError("종료일은 시작일 이후여야 합니다")
        return v

    @property
    def days(self) -> int:
        """여행 일수."""
        return (self.end - self.start).days + 1


class Budget(BaseModel):
    """예산 정보."""
    estimated: int = Field(..., ge=0, description="예상 총 비용")
    currency: str = Field(default="KRW", description="통화")


class Trip(BaseModel):
    """여행 정보."""
    id: str = Field(..., description="여행 ID")
    destination: str = Field(..., min_length=1, max_length=100, description="목적지")
    period: TripPeriod = Field(..., description="여행 기간")
    travelers: int = Field(default=1, ge=1, le=50, description="여행 인원")
    total_budget: Budget = Field(..., description="예산")
    styles: List[TravelStyle] = Field(default_factory=list, description="여행 스타일")
    daily_plans: List[DailyPlan] = Field(default_factory=list, description="일별 계획")
    status: TripStatus = Field(default=TripStatus.UPCOMING, description="상태")
    created_at: datetime = Field(default_factory=datetime.now, description="생성 시간")
    image_url: Optional[str] = Field(default=None, description="대표 이미지")

    class Config:
        json_schema_extra = {
            "example": {
                "id": "trip_123",
                "destination": "오사카",
                "period": {"start": "2026-03-01", "end": "2026-03-04"},
                "travelers": 2,
                "total_budget": {"estimated": 850000, "currency": "KRW"},
                "styles": ["food", "sightseeing"],
                "daily_plans": [],
                "status": "upcoming"
            }
        }


class DecoratedPhoto(BaseModel):
    """꾸며진 사진."""
    id: str = Field(..., description="사진 ID")
    trip_id: str = Field(..., description="연결된 여행 ID")
    original_filename: str = Field(..., description="원본 파일명")
    style: str = Field(..., description="적용된 스타일")
    result_image_base64: str = Field(..., description="결과 이미지 Base64")
    result_mime_type: str = Field(default="image/jpeg", description="결과 MIME 타입")
    created_at: datetime = Field(default_factory=datetime.now, description="생성 시간")
