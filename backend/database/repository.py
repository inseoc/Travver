"""Data access layer for SQLite database."""

import json
from datetime import datetime, date
from typing import List, Optional

import aiosqlite

from models.travel import (
    Trip, TripPeriod, Budget, DailyPlan, Schedule, Location,
    TravelStyle, PlaceCategory, TripStatus, DecoratedPhoto,
)


class TripRepository:
    """여행 데이터 CRUD."""

    def __init__(self, conn: aiosqlite.Connection):
        self.conn = conn

    async def get_all(
        self,
        status_filter: Optional[TripStatus] = None,
        limit: int = 20,
        offset: int = 0,
    ) -> List[Trip]:
        """모든 여행 조회 (daily_plans + schedules 포함)."""
        query = "SELECT * FROM trips"
        params: list = []

        if status_filter:
            query += " WHERE status = ?"
            params.append(status_filter.value)

        query += " ORDER BY created_at DESC LIMIT ? OFFSET ?"
        params.extend([limit, offset])

        async with self.conn.execute(query, params) as cursor:
            rows = await cursor.fetchall()

        trips = []
        for row in rows:
            trip = await self._build_trip(dict(row))
            trips.append(trip)
        return trips

    async def get_by_id(self, trip_id: str) -> Optional[Trip]:
        """특정 여행 조회."""
        async with self.conn.execute(
            "SELECT * FROM trips WHERE id = ?", [trip_id]
        ) as cursor:
            row = await cursor.fetchone()

        if row is None:
            return None
        return await self._build_trip(dict(row))

    async def create(self, trip: Trip) -> Trip:
        """여행 저장 (trip + daily_plans + schedules)."""
        now = datetime.now().isoformat()
        styles_json = json.dumps([s.value for s in trip.styles])

        await self.conn.execute(
            """INSERT INTO trips
            (id, destination, period_start, period_end, travelers,
             budget_estimated, budget_currency, styles,
             custom_preference, accommodation_location,
             status, image_url, created_at, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
            [
                trip.id,
                trip.destination,
                trip.period.start.isoformat(),
                trip.period.end.isoformat(),
                trip.travelers,
                trip.total_budget.estimated,
                trip.total_budget.currency,
                styles_json,
                None,  # custom_preference (not in current Trip model)
                None,  # accommodation_location
                trip.status.value,
                trip.image_url,
                trip.created_at.isoformat(),
                now,
            ],
        )

        # daily_plans + schedules 저장
        for plan in trip.daily_plans:
            cursor = await self.conn.execute(
                """INSERT INTO daily_plans (trip_id, day, date, theme)
                VALUES (?, ?, ?, ?)""",
                [trip.id, plan.day, plan.plan_date.isoformat(), plan.theme],
            )
            daily_plan_id = cursor.lastrowid

            for schedule in plan.schedules:
                await self.conn.execute(
                    """INSERT INTO schedules
                    (daily_plan_id, order_index, time, place, category,
                     duration_min, estimated_cost, description,
                     latitude, longitude, image_url, rating, place_id)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                    [
                        daily_plan_id,
                        schedule.order,
                        schedule.time,
                        schedule.place,
                        schedule.category.value,
                        schedule.duration_min,
                        schedule.estimated_cost,
                        schedule.description,
                        schedule.location.lat,
                        schedule.location.lng,
                        schedule.image_url,
                        schedule.rating,
                        schedule.place_id,
                    ],
                )

        await self.conn.commit()
        return trip

    async def update(self, trip_id: str, trip: Trip) -> Trip:
        """여행 업데이트 (전체 교체 방식)."""
        now = datetime.now().isoformat()
        styles_json = json.dumps([s.value for s in trip.styles])

        await self.conn.execute(
            """UPDATE trips SET
            destination = ?, period_start = ?, period_end = ?,
            travelers = ?, budget_estimated = ?, budget_currency = ?,
            styles = ?, status = ?, image_url = ?, updated_at = ?
            WHERE id = ?""",
            [
                trip.destination,
                trip.period.start.isoformat(),
                trip.period.end.isoformat(),
                trip.travelers,
                trip.total_budget.estimated,
                trip.total_budget.currency,
                styles_json,
                trip.status.value,
                trip.image_url,
                now,
                trip_id,
            ],
        )

        # daily_plans 재생성 (cascade 삭제)
        await self.conn.execute(
            "DELETE FROM daily_plans WHERE trip_id = ?", [trip_id]
        )

        for plan in trip.daily_plans:
            cursor = await self.conn.execute(
                """INSERT INTO daily_plans (trip_id, day, date, theme)
                VALUES (?, ?, ?, ?)""",
                [trip_id, plan.day, plan.plan_date.isoformat(), plan.theme],
            )
            daily_plan_id = cursor.lastrowid

            for schedule in plan.schedules:
                await self.conn.execute(
                    """INSERT INTO schedules
                    (daily_plan_id, order_index, time, place, category,
                     duration_min, estimated_cost, description,
                     latitude, longitude, image_url, rating, place_id)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                    [
                        daily_plan_id,
                        schedule.order,
                        schedule.time,
                        schedule.place,
                        schedule.category.value,
                        schedule.duration_min,
                        schedule.estimated_cost,
                        schedule.description,
                        schedule.location.lat,
                        schedule.location.lng,
                        schedule.image_url,
                        schedule.rating,
                        schedule.place_id,
                    ],
                )

        await self.conn.commit()
        trip.id = trip_id
        return trip

    async def delete(self, trip_id: str) -> bool:
        """여행 삭제 (cascade로 daily_plans, schedules 자동 삭제)."""
        cursor = await self.conn.execute(
            "DELETE FROM trips WHERE id = ?", [trip_id]
        )
        await self.conn.commit()
        return cursor.rowcount > 0

    async def update_status(self, trip_id: str, new_status: TripStatus) -> Optional[Trip]:
        """여행 상태 업데이트."""
        now = datetime.now().isoformat()
        await self.conn.execute(
            "UPDATE trips SET status = ?, updated_at = ? WHERE id = ?",
            [new_status.value, now, trip_id],
        )
        await self.conn.commit()
        return await self.get_by_id(trip_id)

    async def _build_trip(self, row: dict) -> Trip:
        """DB 행으로부터 Trip 객체 빌드."""
        # daily_plans 조회
        async with self.conn.execute(
            "SELECT * FROM daily_plans WHERE trip_id = ? ORDER BY day ASC",
            [row["id"]],
        ) as cursor:
            plan_rows = await cursor.fetchall()

        daily_plans = []
        for plan_row in plan_rows:
            plan_dict = dict(plan_row)

            # schedules 조회
            async with self.conn.execute(
                "SELECT * FROM schedules WHERE daily_plan_id = ? ORDER BY order_index ASC",
                [plan_dict["id"]],
            ) as cursor:
                schedule_rows = await cursor.fetchall()

            schedules = []
            for s in schedule_rows:
                sd = dict(s)
                schedules.append(Schedule(
                    order=sd["order_index"],
                    time=sd["time"],
                    place=sd["place"],
                    category=PlaceCategory(sd["category"]),
                    duration_min=sd["duration_min"],
                    estimated_cost=sd["estimated_cost"],
                    description=sd["description"],
                    location=Location(lat=sd["latitude"], lng=sd["longitude"]),
                    image_url=sd.get("image_url"),
                    rating=sd.get("rating"),
                    place_id=sd.get("place_id"),
                ))

            daily_plans.append(DailyPlan(
                day=plan_dict["day"],
                date=date.fromisoformat(plan_dict["date"]),
                theme=plan_dict["theme"],
                schedules=schedules,
            ))

        # styles 파싱
        styles_raw = json.loads(row.get("styles", "[]"))
        styles = [TravelStyle(s) for s in styles_raw]

        return Trip(
            id=row["id"],
            destination=row["destination"],
            period=TripPeriod(
                start=date.fromisoformat(row["period_start"]),
                end=date.fromisoformat(row["period_end"]),
            ),
            travelers=row["travelers"],
            total_budget=Budget(
                estimated=row["budget_estimated"],
                currency=row["budget_currency"],
            ),
            styles=styles,
            daily_plans=daily_plans,
            status=TripStatus(row["status"]),
            created_at=datetime.fromisoformat(row["created_at"]),
            image_url=row.get("image_url"),
        )


class PhotoRepository:
    """꾸며진 사진 데이터 CRUD."""

    def __init__(self, conn: aiosqlite.Connection):
        self.conn = conn

    async def save(self, photo: DecoratedPhoto) -> DecoratedPhoto:
        """사진 저장."""
        await self.conn.execute(
            """INSERT OR REPLACE INTO decorated_photos
            (id, trip_id, original_filename, style,
             result_image_base64, result_mime_type, created_at)
            VALUES (?, ?, ?, ?, ?, ?, ?)""",
            [
                photo.id,
                photo.trip_id,
                photo.original_filename,
                photo.style,
                photo.result_image_base64,
                photo.result_mime_type,
                photo.created_at.isoformat(),
            ],
        )
        await self.conn.commit()
        return photo

    async def get_by_trip_id(self, trip_id: str) -> List[DecoratedPhoto]:
        """여행별 사진 목록."""
        async with self.conn.execute(
            "SELECT * FROM decorated_photos WHERE trip_id = ? ORDER BY created_at DESC",
            [trip_id],
        ) as cursor:
            rows = await cursor.fetchall()

        return [self._build_photo(dict(row)) for row in rows]

    async def delete(self, photo_id: str) -> bool:
        """사진 삭제."""
        cursor = await self.conn.execute(
            "DELETE FROM decorated_photos WHERE id = ?", [photo_id]
        )
        await self.conn.commit()
        return cursor.rowcount > 0

    def _build_photo(self, row: dict) -> DecoratedPhoto:
        return DecoratedPhoto(
            id=row["id"],
            trip_id=row["trip_id"],
            original_filename=row["original_filename"],
            style=row["style"],
            result_image_base64=row["result_image_base64"],
            result_mime_type=row.get("result_mime_type", "image/jpeg"),
            created_at=datetime.fromisoformat(row["created_at"]),
        )


class ChatMessageRepository:
    """채팅 메시지 데이터 CRUD."""

    def __init__(self, conn: aiosqlite.Connection):
        self.conn = conn

    async def save(
        self,
        message_id: str,
        role: str,
        content: str,
        timestamp: str,
        trip_id: Optional[str] = None,
        status: str = "sent",
        is_tool_call: bool = False,
        tool_name: Optional[str] = None,
    ):
        """메시지 저장."""
        await self.conn.execute(
            """INSERT OR REPLACE INTO chat_messages
            (id, trip_id, role, content, status, is_tool_call, tool_name, timestamp)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
            [
                message_id,
                trip_id,
                role,
                content,
                status,
                1 if is_tool_call else 0,
                tool_name,
                timestamp,
            ],
        )
        await self.conn.commit()

    async def get_by_trip_id(self, trip_id: Optional[str]) -> List[dict]:
        """여행별 메시지 목록."""
        if trip_id:
            query = "SELECT * FROM chat_messages WHERE trip_id = ? ORDER BY timestamp ASC"
            params = [trip_id]
        else:
            query = "SELECT * FROM chat_messages WHERE trip_id IS NULL ORDER BY timestamp ASC"
            params = []

        async with self.conn.execute(query, params) as cursor:
            rows = await cursor.fetchall()

        return [dict(row) for row in rows]

    async def delete_by_trip_id(self, trip_id: Optional[str]):
        """여행별 메시지 삭제."""
        if trip_id:
            await self.conn.execute(
                "DELETE FROM chat_messages WHERE trip_id = ?", [trip_id]
            )
        else:
            await self.conn.execute(
                "DELETE FROM chat_messages WHERE trip_id IS NULL"
            )
        await self.conn.commit()
