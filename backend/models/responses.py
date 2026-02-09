"""API response models."""

from typing import Any, List, Optional
from pydantic import BaseModel, Field

from .travel import Trip, DecoratedPhoto


class ErrorResponse(BaseModel):
    """에러 응답."""
    success: bool = Field(default=False, description="성공 여부")
    error: str = Field(..., description="에러 코드")
    message: str = Field(..., description="에러 메시지")
    details: Optional[Any] = Field(default=None, description="상세 정보")

    class Config:
        json_schema_extra = {
            "example": {
                "success": False,
                "error": "VALIDATION_ERROR",
                "message": "입력값이 올바르지 않습니다",
                "details": {"field": "destination", "issue": "required"},
            }
        }


class HealthResponse(BaseModel):
    """헬스체크 응답."""
    status: str = Field(default="healthy", description="서버 상태")
    version: str = Field(default="1.0.0", description="API 버전")
    services: dict = Field(default_factory=dict, description="서비스 상태")

    class Config:
        json_schema_extra = {
            "example": {
                "status": "healthy",
                "version": "1.0.0",
                "services": {
                    "openai": True,
                    "gemini": True,
                    "database": True,
                },
            }
        }


class TravelPlanResponse(BaseModel):
    """여행 일정 생성 응답."""
    success: bool = Field(default=True, description="성공 여부")
    trip: Trip = Field(..., description="생성된 여행 일정")
    message: str = Field(default="일정이 생성되었습니다", description="응답 메시지")

    class Config:
        json_schema_extra = {
            "example": {
                "success": True,
                "trip": {
                    "id": "trip_123",
                    "destination": "오사카",
                    "period": {"start": "2026-03-01", "end": "2026-03-04"},
                },
                "message": "일정이 생성되었습니다",
            }
        }


class ConsultantResponse(BaseModel):
    """AI 컨설턴트 응답."""
    success: bool = Field(default=True, description="성공 여부")
    response: str = Field(..., description="AI 응답 메시지")
    tools_used: list = Field(default_factory=list, description="사용된 도구 목록")

    class Config:
        json_schema_extra = {
            "example": {
                "success": True,
                "response": "현재 위치 기준 추천 라멘집 3곳입니다...",
                "tools_used": ["search_places"],
            }
        }


class PhotoDecorateResponse(BaseModel):
    """사진 꾸미기 응답."""
    success: bool = Field(default=True, description="성공 여부")
    result_url: str = Field(..., description="결과 이미지 URL")
    original_url: str = Field(..., description="원본 이미지 URL")
    style: str = Field(..., description="적용된 스타일")
    result_image_base64: Optional[str] = Field(default=None, description="결과 이미지 Base64 데이터")
    result_mime_type: Optional[str] = Field(default=None, description="결과 이미지 MIME 타입")

    class Config:
        json_schema_extra = {
            "example": {
                "success": True,
                "result_url": "https://storage.example.com/decorated/123.jpg",
                "original_url": "https://storage.example.com/original/123.jpg",
                "style": "watercolor",
                "result_image_base64": "<base64-encoded-image>",
                "result_mime_type": "image/jpeg",
            }
        }


class VideoCreateResponse(BaseModel):
    """영상 생성 응답."""
    success: bool = Field(default=True, description="성공 여부")
    result_url: str = Field(..., description="결과 영상 URL")
    thumbnail_url: str = Field(..., description="썸네일 URL")
    duration: int = Field(..., description="영상 길이 (초)")
    style: str = Field(..., description="적용된 스타일")
    aspect_ratio: str = Field(default="16:9", description="영상 가로세로 비율 (16:9 또는 9:16)")
    result_video_base64: Optional[str] = Field(default=None, description="결과 영상 Base64 데이터")
    result_mime_type: Optional[str] = Field(default=None, description="결과 영상 MIME 타입")

    class Config:
        json_schema_extra = {
            "example": {
                "success": True,
                "result_url": "https://storage.example.com/videos/123.mp4",
                "thumbnail_url": "https://storage.example.com/thumbnails/123.jpg",
                "duration": 30,
                "style": "cinematic",
                "aspect_ratio": "16:9",
                "result_video_base64": "<base64-encoded-video>",
                "result_mime_type": "video/mp4",
            }
        }


class DecoratedPhotoListResponse(BaseModel):
    """꾸며진 사진 목록 응답."""
    success: bool = Field(default=True)
    photos: List[DecoratedPhoto] = Field(default_factory=list)
    count: int = Field(default=0)
