"""Memories API routes - 사진 꾸미기 / 영상 생성."""

import base64
from typing import List
from fastapi import APIRouter, HTTPException, UploadFile, File, Form, status

from core.logger import logger
from core.exceptions import GeminiException, RateLimitException
from models.requests import PhotoDecorateRequest, VideoCreateRequest
from models.responses import PhotoDecorateResponse, VideoCreateResponse, ErrorResponse
from services.gemini_service import gemini_service

router = APIRouter(prefix="/memories", tags=["Memories"])


@router.post(
    "/photo",
    response_model=PhotoDecorateResponse,
    responses={
        400: {"model": ErrorResponse, "description": "잘못된 요청"},
        500: {"model": ErrorResponse, "description": "서버 오류"},
    },
    summary="사진 꾸미기",
    description="AI를 사용하여 여행 사진을 예술적으로 꾸밉니다.",
)
async def decorate_photo(
    image: UploadFile = File(..., description="원본 이미지"),
    style: str = Form(..., description="적용할 스타일"),
    trip_id: str = Form(None, description="여행 ID"),
) -> PhotoDecorateResponse:
    """
    AI로 사진을 꾸밉니다.

    - **image**: 원본 이미지 파일 (JPG, PNG)
    - **style**: 스타일 (watercolor, oil_painting, sketch, vintage, movie_poster, pop_art)
    - **trip_id**: 여행 ID (선택)
    """
    # 파일 검증
    if not image.content_type or not image.content_type.startswith("image/"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error": "INVALID_FILE", "message": "이미지 파일만 업로드 가능합니다."},
        )

    # 파일 크기 제한 (10MB)
    contents = await image.read()
    if len(contents) > 10 * 1024 * 1024:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error": "FILE_TOO_LARGE", "message": "파일 크기는 10MB 이하여야 합니다."},
        )

    # 스타일 검증
    valid_styles = ["watercolor", "oil_painting", "sketch", "vintage", "movie_poster", "pop_art"]
    if style not in valid_styles:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error": "INVALID_STYLE", "message": f"유효하지 않은 스타일입니다. 가능한 값: {valid_styles}"},
        )

    logger.info(f"Photo decoration request: style={style}, size={len(contents)} bytes")

    try:
        # 이미지 포맷 추출
        image_format = "jpeg"
        if image.content_type:
            image_format = image.content_type.split("/")[-1]
            if image_format == "jpg":
                image_format = "jpeg"

        # Gemini로 사진 변환
        result_data = await gemini_service.decorate_photo(
            image_data=contents,
            style=style,
            image_format=image_format,
        )

        # Base64 인코딩하여 클라이언트에 직접 전달
        result_base64 = base64.b64encode(result_data).decode("utf-8")
        mime_type = f"image/{image_format}"

        # placeholder URL (향후 S3 업로드 시 실제 URL로 대체)
        result_url = f"https://storage.travver.app/decorated/{image.filename}"
        original_url = f"https://storage.travver.app/original/{image.filename}"

        return PhotoDecorateResponse(
            success=True,
            result_url=result_url,
            original_url=original_url,
            style=style,
            result_image_base64=result_base64,
            result_mime_type=mime_type,
        )

    except RateLimitException as e:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail={"error": "RATE_LIMIT", "message": "요청이 너무 많습니다. 잠시 후 다시 시도해주세요."},
        )

    except GeminiException as e:
        logger.error(f"Gemini error: {e.message}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": "AI_ERROR", "message": "이미지 처리 중 오류가 발생했습니다."},
        )

    except Exception as e:
        logger.exception(f"Unexpected error in photo decoration: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": "INTERNAL_ERROR", "message": "서버 오류가 발생했습니다."},
        )


@router.post(
    "/video",
    response_model=VideoCreateResponse,
    responses={
        400: {"model": ErrorResponse, "description": "잘못된 요청"},
        500: {"model": ErrorResponse, "description": "서버 오류"},
    },
    summary="AI 영상 생성",
    description="AI를 사용하여 여행 영상을 생성합니다.",
)
async def create_video(
    media: List[UploadFile] = File(..., description="미디어 파일들"),
    style: str = Form(..., description="영상 스타일"),
    music: str = Form("calm", description="배경음악"),
    duration: int = Form(30, description="영상 길이 (초)"),
    aspect_ratio: str = Form("16:9", description="가로세로 비율 (16:9 또는 9:16)"),
    trip_id: str = Form(None, description="여행 ID"),
) -> VideoCreateResponse:
    """
    AI로 여행 영상을 생성합니다.

    - **media**: 미디어 파일들 (이미지/영상)
    - **style**: 영상 스타일 (cinematic, vlog, highlight, album)
    - **music**: 배경음악 (calm, upbeat, emotional, none)
    - **duration**: 영상 길이 (15, 30, 60초)
    - **aspect_ratio**: 가로세로 비율 (16:9 가로, 9:16 세로)
    - **trip_id**: 여행 ID (선택)
    """
    # 파일 개수 제한
    if len(media) < 1:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error": "NO_MEDIA", "message": "최소 1개 이상의 미디어가 필요합니다."},
        )

    if len(media) > 25:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error": "TOO_MANY_FILES", "message": "최대 25개까지 업로드 가능합니다."},
        )

    # 스타일 검증
    valid_styles = ["cinematic", "vlog", "highlight", "album"]
    if style not in valid_styles:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error": "INVALID_STYLE", "message": f"유효하지 않은 스타일입니다. 가능한 값: {valid_styles}"},
        )

    # 음악 검증
    valid_music = ["calm", "upbeat", "emotional", "none"]
    if music not in valid_music:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error": "INVALID_MUSIC", "message": f"유효하지 않은 음악입니다. 가능한 값: {valid_music}"},
        )

    # 길이 검증
    if duration not in [15, 30, 60]:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error": "INVALID_DURATION", "message": "영상 길이는 15, 30, 60초 중 선택해주세요."},
        )

    # 가로세로 비율 검증
    valid_aspect_ratios = ["16:9", "9:16"]
    if aspect_ratio not in valid_aspect_ratios:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error": "INVALID_ASPECT_RATIO", "message": f"유효하지 않은 비율입니다. 가능한 값: {valid_aspect_ratios}"},
        )

    logger.info(f"Video creation request: style={style}, music={music}, duration={duration}s, aspect_ratio={aspect_ratio}, files={len(media)}")

    try:
        # 미디어 파일 읽기
        media_contents = []
        total_size = 0
        max_size = 100 * 1024 * 1024  # 100MB 총 제한

        for file in media:
            content = await file.read()
            total_size += len(content)

            if total_size > max_size:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail={"error": "FILES_TOO_LARGE", "message": "총 파일 크기는 100MB 이하여야 합니다."},
                )

            media_contents.append(content)

        # Gemini Veo로 영상 생성
        result_data = await gemini_service.create_video(
            media_files=media_contents,
            style=style,
            music=music,
            duration=duration,
            aspect_ratio=aspect_ratio,
        )

        # 실제로는 S3 등에 업로드하고 URL 반환
        import uuid
        video_id = uuid.uuid4().hex[:12]

        return VideoCreateResponse(
            success=True,
            result_url=f"https://storage.travver.app/videos/{video_id}.mp4",
            thumbnail_url=f"https://storage.travver.app/thumbnails/{video_id}.jpg",
            duration=duration,
            style=style,
            aspect_ratio=aspect_ratio,
        )

    except RateLimitException as e:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail={"error": "RATE_LIMIT", "message": "요청이 너무 많습니다. 잠시 후 다시 시도해주세요."},
        )

    except GeminiException as e:
        logger.error(f"Gemini Veo error: {e.message}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": "AI_ERROR", "message": "영상 생성 중 오류가 발생했습니다."},
        )

    except Exception as e:
        logger.exception(f"Unexpected error in video creation: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": "INTERNAL_ERROR", "message": "서버 오류가 발생했습니다."},
        )


@router.get(
    "/styles/photo",
    summary="사진 스타일 목록",
    description="사용 가능한 사진 스타일 목록을 반환합니다.",
)
async def get_photo_styles():
    """사용 가능한 사진 스타일 목록."""
    return {
        "styles": [
            {"id": "watercolor", "name": "수채화", "description": "부드러운 수채화 스타일"},
            {"id": "oil_painting", "name": "유화", "description": "클래식 유화 스타일"},
            {"id": "sketch", "name": "스케치", "description": "연필 스케치 스타일"},
            {"id": "vintage", "name": "빈티지", "description": "레트로 빈티지 스타일"},
            {"id": "movie_poster", "name": "영화 포스터", "description": "드라마틱한 영화 포스터 스타일"},
            {"id": "pop_art", "name": "팝아트", "description": "화려한 팝아트 스타일"},
        ]
    }


@router.get(
    "/styles/video",
    summary="영상 스타일 목록",
    description="사용 가능한 영상 스타일 목록을 반환합니다.",
)
async def get_video_styles():
    """사용 가능한 영상 스타일 목록."""
    return {
        "styles": [
            {"id": "cinematic", "name": "시네마틱 여행", "description": "드라마틱한 영화 같은 영상"},
            {"id": "vlog", "name": "감성 브이로그", "description": "자연스러운 브이로그 스타일"},
            {"id": "highlight", "name": "다이나믹 하이라이트", "description": "빠른 편집의 하이라이트 릴"},
            {"id": "album", "name": "추억 앨범", "description": "부드러운 추억 앨범 스타일"},
        ],
        "music_options": [
            {"id": "calm", "name": "잔잔한"},
            {"id": "upbeat", "name": "신나는"},
            {"id": "emotional", "name": "감성적인"},
            {"id": "none", "name": "없음"},
        ],
        "duration_options": [15, 30, 60],
        "aspect_ratio_options": [
            {"id": "16:9", "name": "가로 (16:9)", "description": "가로 영상 (기본값)"},
            {"id": "9:16", "name": "세로 (9:16)", "description": "세로 영상 (릴스/숏츠용)"},
        ],
    }
