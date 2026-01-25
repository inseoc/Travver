"""API request models."""

from datetime import date
from typing import List, Optional
from pydantic import BaseModel, Field, field_validator

from .travel import TravelStyle


class TravelPlanRequest(BaseModel):
    """여행 일정 생성 요청."""
    destination: str = Field(
        ...,
        min_length=1,
        max_length=100,
        description="목적지 (도시 또는 국가)",
    )
    start_date: date = Field(..., description="여행 시작일")
    end_date: date = Field(..., description="여행 종료일")
    travelers: int = Field(default=2, ge=1, le=50, description="여행 인원")
    budget: int = Field(
        default=500000,
        ge=0,
        le=50000000,
        description="1인당 예산 (KRW)",
    )
    styles: List[TravelStyle] = Field(
        default_factory=list,
        description="여행 스타일",
    )
    accommodation_location: Optional[str] = Field(
        default=None,
        max_length=200,
        description="숙소 위치 (예: 난바역, 제주시청 근처)",
    )
    custom_preference: Optional[str] = Field(
        default=None,
        max_length=500,
        description="사용자 커스텀 선호도 (자유 입력)",
    )

    @field_validator("end_date")
    @classmethod
    def validate_dates(cls, v: date, info) -> date:
        """날짜 유효성 검증."""
        if "start_date" in info.data:
            if v < info.data["start_date"]:
                raise ValueError("종료일은 시작일 이후여야 합니다")
            days = (v - info.data["start_date"]).days + 1
            if days > 30:
                raise ValueError("여행 기간은 최대 30일까지 가능합니다")
        return v

    @field_validator("styles")
    @classmethod
    def validate_styles(cls, v: List[TravelStyle]) -> List[TravelStyle]:
        """스타일 유효성 검증."""
        if len(v) > 6:
            raise ValueError("여행 스타일은 최대 6개까지 선택 가능합니다")
        return v

    class Config:
        json_schema_extra = {
            "example": {
                "destination": "오사카",
                "start_date": "2026-03-01",
                "end_date": "2026-03-04",
                "travelers": 2,
                "budget": 500000,
                "styles": ["food", "sightseeing"],
                "accommodation_location": "난바역",
                "custom_preference": "현지인 맛집 위주로, 사진 찍기 좋은 카페 포함",
            }
        }


class ChatMessage(BaseModel):
    """채팅 메시지."""
    role: str = Field(..., pattern="^(user|assistant|system)$", description="메시지 역할")
    content: str = Field(..., min_length=1, max_length=4000, description="메시지 내용")


class ConsultantRequest(BaseModel):
    """AI 컨설턴트 요청."""
    message: str = Field(
        ...,
        min_length=1,
        max_length=2000,
        description="사용자 메시지",
    )
    history: List[ChatMessage] = Field(
        default_factory=list,
        description="대화 히스토리",
    )
    trip_id: Optional[str] = Field(
        default=None,
        description="현재 여행 ID (컨텍스트용)",
    )

    @field_validator("history")
    @classmethod
    def validate_history(cls, v: List[ChatMessage]) -> List[ChatMessage]:
        """히스토리 길이 제한."""
        if len(v) > 50:
            # 최근 50개만 유지
            return v[-50:]
        return v

    class Config:
        json_schema_extra = {
            "example": {
                "message": "오늘 저녁 근처 라멘 맛집 추천해줘",
                "history": [],
                "trip_id": "trip_123",
            }
        }


class PhotoDecorateRequest(BaseModel):
    """사진 꾸미기 요청."""
    style: str = Field(
        ...,
        description="스타일 (watercolor, oil_painting, sketch, vintage, movie_poster, pop_art)",
    )
    trip_id: Optional[str] = Field(default=None, description="여행 ID")

    @field_validator("style")
    @classmethod
    def validate_style(cls, v: str) -> str:
        """스타일 유효성 검증."""
        valid_styles = [
            "watercolor", "oil_painting", "sketch",
            "vintage", "movie_poster", "pop_art"
        ]
        if v not in valid_styles:
            raise ValueError(f"유효하지 않은 스타일입니다. 가능한 값: {valid_styles}")
        return v


class VideoCreateRequest(BaseModel):
    """영상 생성 요청."""
    style: str = Field(
        ...,
        description="영상 스타일 (cinematic, vlog, highlight, album)",
    )
    music: str = Field(
        default="calm",
        description="배경음악 (calm, upbeat, emotional, none)",
    )
    duration: int = Field(
        default=30,
        ge=15,
        le=60,
        description="영상 길이 (초)",
    )
    trip_id: Optional[str] = Field(default=None, description="여행 ID")

    @field_validator("style")
    @classmethod
    def validate_style(cls, v: str) -> str:
        """스타일 유효성 검증."""
        valid_styles = ["cinematic", "vlog", "highlight", "album"]
        if v not in valid_styles:
            raise ValueError(f"유효하지 않은 스타일입니다. 가능한 값: {valid_styles}")
        return v

    @field_validator("music")
    @classmethod
    def validate_music(cls, v: str) -> str:
        """음악 유효성 검증."""
        valid_music = ["calm", "upbeat", "emotional", "none"]
        if v not in valid_music:
            raise ValueError(f"유효하지 않은 음악입니다. 가능한 값: {valid_music}")
        return v
