"""Travel CRUD API routes."""

from typing import List, Optional
from fastapi import APIRouter, HTTPException, status, Query

from core.logger import logger
from models.travel import Trip, TripStatus
from models.responses import ErrorResponse

router = APIRouter(prefix="/travel", tags=["Travel"])

# In-memory storage (실제로는 DB 사용)
_trips_db: dict[str, Trip] = {}


@router.get(
    "/trips",
    response_model=List[Trip],
    summary="여행 목록 조회",
    description="저장된 모든 여행 목록을 조회합니다.",
)
async def get_trips(
    status_filter: Optional[TripStatus] = Query(None, description="상태 필터"),
    limit: int = Query(20, ge=1, le=100, description="최대 조회 개수"),
    offset: int = Query(0, ge=0, description="건너뛸 개수"),
) -> List[Trip]:
    """
    여행 목록을 조회합니다.

    - **status_filter**: 상태로 필터링 (upcoming, ongoing, completed)
    - **limit**: 최대 조회 개수
    - **offset**: 페이지네이션 오프셋
    """
    trips = list(_trips_db.values())

    if status_filter:
        trips = [t for t in trips if t.status == status_filter]

    # 최신순 정렬
    trips.sort(key=lambda t: t.created_at, reverse=True)

    return trips[offset:offset + limit]


@router.get(
    "/trips/{trip_id}",
    response_model=Trip,
    responses={404: {"model": ErrorResponse}},
    summary="여행 상세 조회",
    description="특정 여행의 상세 정보를 조회합니다.",
)
async def get_trip(trip_id: str) -> Trip:
    """
    특정 여행을 조회합니다.

    - **trip_id**: 여행 ID
    """
    if trip_id not in _trips_db:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"error": "NOT_FOUND", "message": "여행을 찾을 수 없습니다."},
        )

    return _trips_db[trip_id]


@router.post(
    "/trips",
    response_model=Trip,
    status_code=status.HTTP_201_CREATED,
    summary="여행 저장",
    description="새 여행을 저장합니다.",
)
async def create_trip(trip: Trip) -> Trip:
    """
    새 여행을 저장합니다.

    - **trip**: 저장할 여행 정보
    """
    logger.info(f"Saving trip: {trip.id} - {trip.destination}")

    _trips_db[trip.id] = trip
    return trip


@router.put(
    "/trips/{trip_id}",
    response_model=Trip,
    responses={404: {"model": ErrorResponse}},
    summary="여행 수정",
    description="기존 여행을 수정합니다.",
)
async def update_trip(trip_id: str, trip: Trip) -> Trip:
    """
    기존 여행을 수정합니다.

    - **trip_id**: 여행 ID
    - **trip**: 수정할 여행 정보
    """
    if trip_id not in _trips_db:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"error": "NOT_FOUND", "message": "여행을 찾을 수 없습니다."},
        )

    logger.info(f"Updating trip: {trip_id}")

    trip.id = trip_id  # ID 유지
    _trips_db[trip_id] = trip
    return trip


@router.delete(
    "/trips/{trip_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    responses={404: {"model": ErrorResponse}},
    summary="여행 삭제",
    description="여행을 삭제합니다.",
)
async def delete_trip(trip_id: str):
    """
    여행을 삭제합니다.

    - **trip_id**: 여행 ID
    """
    if trip_id not in _trips_db:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"error": "NOT_FOUND", "message": "여행을 찾을 수 없습니다."},
        )

    logger.info(f"Deleting trip: {trip_id}")

    del _trips_db[trip_id]


@router.patch(
    "/trips/{trip_id}/status",
    response_model=Trip,
    responses={404: {"model": ErrorResponse}},
    summary="여행 상태 변경",
    description="여행의 상태를 변경합니다.",
)
async def update_trip_status(trip_id: str, new_status: TripStatus) -> Trip:
    """
    여행 상태를 변경합니다.

    - **trip_id**: 여행 ID
    - **new_status**: 새 상태 (upcoming, ongoing, completed)
    """
    if trip_id not in _trips_db:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail={"error": "NOT_FOUND", "message": "여행을 찾을 수 없습니다."},
        )

    logger.info(f"Updating trip status: {trip_id} -> {new_status}")

    trip = _trips_db[trip_id]
    trip.status = new_status
    return trip
