"""Agent API routes - AI 일정 생성."""

from fastapi import APIRouter, HTTPException, status

from core.logger import logger
from core.exceptions import AIServiceException, ValidationException
from models.requests import TravelPlanRequest, ModifyDayRequest
from models.responses import TravelPlanResponse, ModifyDayResponse, ErrorResponse
from agents import travel_planner_agent
from database import db
from database.repository import TripRepository

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

        # 생성된 여행을 SQLite에 저장
        try:
            repo = TripRepository(db.connection)
            await repo.create(trip)
            logger.info(f"Trip saved to database: {trip.id}")
        except Exception as save_err:
            logger.warning(f"Failed to save trip to database: {save_err}")

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
    "/modify-day",
    response_model=ModifyDayResponse,
    responses={
        400: {"model": ErrorResponse, "description": "잘못된 요청"},
        500: {"model": ErrorResponse, "description": "서버 오류"},
    },
    summary="AI 일정 수정 (Day 단위)",
    description="특정 Day의 일정을 사용자 프롬프트 기반으로 수정합니다.",
)
async def modify_day_plan(request: ModifyDayRequest) -> ModifyDayResponse:
    """
    특정 Day의 일정을 AI로 수정합니다.

    - **trip_id**: 여행 ID
    - **day**: 수정할 Day 번호
    - **prompt**: 수정 요청 프롬프트 (50자 이내)
    """
    logger.info(f"Modify day request: trip={request.trip_id}, day={request.day}, prompt={request.prompt}")

    try:
        # 여행 정보 조회
        repo = TripRepository(db.connection)
        trip = await repo.get_by_id(request.trip_id)
        if not trip:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail={"error": "NOT_FOUND", "message": "여행을 찾을 수 없습니다."},
            )

        # 해당 Day 일정 수정
        modified_plan = await travel_planner_agent.modify_day_plan(
            trip=trip,
            day=request.day,
            prompt=request.prompt,
        )

        # DB에 수정된 여행 저장
        try:
            # trip의 daily_plans에서 해당 day를 교체
            updated_plans = []
            for plan in trip.daily_plans:
                if plan.day == request.day:
                    updated_plans.append(modified_plan)
                else:
                    updated_plans.append(plan)
            trip.daily_plans = updated_plans
            await repo.update(trip)
            logger.info(f"Updated trip {trip.id} day {request.day}")
        except Exception as save_err:
            logger.warning(f"Failed to update trip in database: {save_err}")

        return ModifyDayResponse(
            success=True,
            daily_plan=modified_plan,
            message=f"Day {request.day} 일정이 수정되었습니다.",
        )

    except HTTPException:
        raise

    except AIServiceException as e:
        logger.error(f"AI service error: {e.message}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": e.code, "message": e.message},
        )

    except Exception as e:
        logger.exception(f"Unexpected error in modify day: {e}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={"error": "INTERNAL_ERROR", "message": "일정 수정 중 오류가 발생했습니다."},
        )
