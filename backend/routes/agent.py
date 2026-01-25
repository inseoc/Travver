"""Agent API routes - AI 일정 생성 및 컨설턴트."""

from fastapi import APIRouter, HTTPException, status
from fastapi.responses import StreamingResponse

from core.logger import logger
from core.exceptions import AIServiceException, ValidationException
from models.requests import TravelPlanRequest, ConsultantRequest
from models.responses import TravelPlanResponse, ConsultantResponse, ErrorResponse
from agents import travel_planner_agent, travel_consultant_agent

router = APIRouter(prefix="/agent", tags=["Agent"])


@router.post(
    "/travel-plan",
    response_model=TravelPlanResponse,
    responses={
        400: {"model": ErrorResponse, "description": "잘못된 요청"},
        500: {"model": ErrorResponse, "description": "서버 오류"},
    },
    summary="AI 여행 일정 생성",
    description="Travel Planner Agent를 사용하여 맞춤형 여행 일정을 생성합니다.",
)
async def generate_travel_plan(request: TravelPlanRequest) -> TravelPlanResponse:
    """
    AI를 사용하여 여행 일정을 생성합니다.

    - **destination**: 여행 목적지 (예: 오사카, 도쿄)
    - **start_date**: 여행 시작일
    - **end_date**: 여행 종료일
    - **travelers**: 여행 인원
    - **budget**: 1인당 예산 (KRW)
    - **styles**: 여행 스타일 목록
    """
    logger.info(f"Travel plan request: {request.destination}")

    try:
        trip = await travel_planner_agent.generate_plan(
            destination=request.destination,
            start_date=request.start_date,
            end_date=request.end_date,
            travelers=request.travelers,
            budget=request.budget,
            styles=request.styles,
            accommodation_location=request.accommodation_location,
            custom_preference=request.custom_preference,
        )

        return TravelPlanResponse(
            success=True,
            trip=trip,
            message=f"{request.destination} {trip.period.days}일 여행 일정이 생성되었습니다.",
        )

    except ValidationException as e:
        logger.warning(f"Validation error: {e.message}")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail={"error": e.code, "message": e.message},
        )

    except AIServiceException as e:
        logger.error(f"AI service error: {e.message}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": e.code, "message": e.message},
        )

    except Exception as e:
        logger.exception(f"Unexpected error in travel plan: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": "INTERNAL_ERROR", "message": "일정 생성 중 오류가 발생했습니다."},
        )


@router.post(
    "/consultant",
    response_model=ConsultantResponse,
    responses={
        400: {"model": ErrorResponse, "description": "잘못된 요청"},
        500: {"model": ErrorResponse, "description": "서버 오류"},
    },
    summary="AI 컨설턴트 채팅",
    description="Travel Consultant Agent와 대화합니다.",
)
async def chat_with_consultant(request: ConsultantRequest) -> ConsultantResponse:
    """
    AI 컨설턴트와 대화합니다.

    - **message**: 사용자 메시지
    - **history**: 이전 대화 기록
    - **trip_id**: 현재 여행 ID (선택)
    """
    logger.info(f"Consultant request: {request.message[:50]}...")

    try:
        # 여행 컨텍스트 조회 (trip_id가 있는 경우)
        trip_context = None
        if request.trip_id:
            # 실제로는 DB에서 조회
            trip_context = {"trip_id": request.trip_id}

        result = await travel_consultant_agent.chat(
            message=request.message,
            history=[h.model_dump() for h in request.history],
            trip_context=trip_context,
        )

        return ConsultantResponse(
            success=True,
            response=result["response"],
            tools_used=result.get("tools_used", []),
        )

    except AIServiceException as e:
        logger.error(f"AI service error: {e.message}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": e.code, "message": e.message},
        )

    except Exception as e:
        logger.exception(f"Unexpected error in consultant: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": "INTERNAL_ERROR", "message": "상담 중 오류가 발생했습니다."},
        )


@router.post(
    "/consultant/stream",
    summary="AI 컨설턴트 스트리밍 채팅",
    description="Travel Consultant Agent와 스트리밍 방식으로 대화합니다.",
)
async def chat_with_consultant_stream(request: ConsultantRequest):
    """
    AI 컨설턴트와 스트리밍 방식으로 대화합니다.

    Server-Sent Events (SSE) 형식으로 응답합니다.
    """
    logger.info(f"Consultant stream request: {request.message[:50]}...")

    async def generate():
        try:
            trip_context = None
            if request.trip_id:
                trip_context = {"trip_id": request.trip_id}

            async for chunk in travel_consultant_agent.chat_stream(
                message=request.message,
                history=[h.model_dump() for h in request.history],
                trip_context=trip_context,
            ):
                yield f"data: {chunk}\n\n"

            yield "data: [DONE]\n\n"

        except Exception as e:
            logger.error(f"Streaming error: {e}")
            yield f"data: [ERROR] {str(e)}\n\n"

    return StreamingResponse(
        generate(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
        },
    )
