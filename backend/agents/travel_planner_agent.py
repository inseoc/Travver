"""Travel Planner Agent - AI 기반 여행 일정 생성."""

import json
import uuid
from datetime import date, datetime, timedelta
from typing import Any, Dict, List, Optional

from core.logger import logger
from core.exceptions import AIServiceException
from services.openai_service import openai_service
from tools import places_tool, exchange_tool
from tools.definitions import TRAVEL_PLANNER_TOOLS
from models.travel import (
    Trip,
    TripPeriod,
    Budget,
    DailyPlan,
    Schedule,
    Location,
    TravelStyle,
    PlaceCategory,
    TripStatus,
)


class TravelPlannerAgent:
    """
    여행 일정 생성 Agent.

    OpenAI GPT를 사용하여 사용자 입력을 기반으로
    최적의 여행 일정을 자동 생성합니다.
    """

    def __init__(self):
        """Initialize Travel Planner Agent."""
        self.system_prompt = self._build_system_prompt()

    def _build_system_prompt(self) -> str:
        """시스템 프롬프트 생성."""
        return """당신은 전문 여행 플래너 AI입니다.
사용자의 여행 정보를 바탕으로 최적의 여행 일정을 생성합니다.

## 역할
- 목적지, 기간, 예산, 여행 스타일에 맞는 일정 생성
- 효율적인 동선 고려 (지역별 그룹핑)
- 현실적인 시간 배분 (이동 시간 포함)
- 예산에 맞는 장소 추천

## 일정 생성 규칙
1. 하루 일정은 보통 4-6개 장소로 구성
2. 아침 9-10시 시작, 저녁 21-22시 종료
3. 식사 시간 고려 (아침, 점심, 저녁)
4. 장소 간 이동 시간 고려 (최소 30분)
5. 각 장소에서 적절한 체류 시간 배분

## 카테고리
- food: 맛집, 레스토랑, 카페
- sightseeing: 관광지, 명소
- accommodation: 숙소
- activity: 액티비티, 체험
- shopping: 쇼핑
- rest: 휴식, 카페

## 출력 형식
반드시 JSON 형식으로 일정을 출력하세요.
각 일정에는 order, time, place, category, duration_min, estimated_cost, description, location(lat, lng)을 포함합니다."""

    async def generate_plan(
        self,
        destination: str,
        start_date: date,
        end_date: date,
        travelers: int,
        budget: int,
        styles: List[TravelStyle],
    ) -> Trip:
        """
        여행 일정을 생성합니다.

        Args:
            destination: 목적지
            start_date: 시작일
            end_date: 종료일
            travelers: 여행 인원
            budget: 1인당 예산 (KRW)
            styles: 여행 스타일

        Returns:
            생성된 Trip 객체
        """
        logger.info(f"Generating travel plan: {destination}, {start_date} - {end_date}")

        try:
            # 1. 환율 정보 조회
            exchange_info = await self._get_exchange_rate(destination)

            # 2. 장소 정보 수집
            places_info = await self._collect_places(destination, styles)

            # 3. AI로 일정 생성
            daily_plans = await self._generate_daily_plans(
                destination=destination,
                start_date=start_date,
                end_date=end_date,
                budget=budget,
                styles=styles,
                places_info=places_info,
                exchange_info=exchange_info,
            )

            # 4. Trip 객체 생성
            trip = Trip(
                id=f"trip_{uuid.uuid4().hex[:12]}",
                destination=destination,
                period=TripPeriod(start=start_date, end=end_date),
                travelers=travelers,
                total_budget=Budget(
                    estimated=budget * travelers,
                    currency="KRW",
                ),
                styles=styles,
                daily_plans=daily_plans,
                status=TripStatus.UPCOMING,
                created_at=datetime.now(),
            )

            logger.info(f"Travel plan generated: {trip.id}, {len(daily_plans)} days")
            return trip

        except Exception as e:
            logger.error(f"Failed to generate travel plan: {e}")
            raise AIServiceException(f"일정 생성 실패: {str(e)}")

    async def _get_exchange_rate(self, destination: str) -> Dict[str, Any]:
        """목적지 통화 환율 조회."""
        # 목적지별 통화 매핑
        currency_map = {
            "일본": "JPY", "오사카": "JPY", "도쿄": "JPY", "교토": "JPY",
            "미국": "USD", "뉴욕": "USD", "LA": "USD",
            "유럽": "EUR", "파리": "EUR", "런던": "GBP",
            "태국": "THB", "방콕": "THB",
            "베트남": "VND", "호치민": "VND", "하노이": "VND",
            "중국": "CNY", "상하이": "CNY", "베이징": "CNY",
        }

        to_currency = "JPY"  # 기본값
        for key, currency in currency_map.items():
            if key in destination:
                to_currency = currency
                break

        return await exchange_tool.get_exchange_rate("KRW", to_currency)

    async def _collect_places(
        self,
        destination: str,
        styles: List[TravelStyle],
    ) -> Dict[str, List[Dict]]:
        """여행 스타일에 맞는 장소 정보 수집."""
        places_info = {}

        # 스타일별 검색 키워드
        style_queries = {
            TravelStyle.FOOD: ["맛집", "레스토랑", "현지 음식"],
            TravelStyle.SIGHTSEEING: ["관광지", "명소", "랜드마크"],
            TravelStyle.RELAXATION: ["온천", "스파", "공원"],
            TravelStyle.ACTIVITY: ["액티비티", "체험", "투어"],
            TravelStyle.SHOPPING: ["쇼핑", "시장", "백화점"],
            TravelStyle.PHOTO: ["포토스팟", "뷰포인트", "인스타그램"],
        }

        for style in styles:
            queries = style_queries.get(style, [style.value])
            style_places = []

            for query in queries:
                try:
                    results = await places_tool.search_places(
                        query=query,
                        location=destination,
                        max_results=5,
                    )
                    style_places.extend(results)
                except Exception as e:
                    logger.warning(f"Failed to search places for {query}: {e}")

            places_info[style.value] = style_places

        return places_info

    async def _generate_daily_plans(
        self,
        destination: str,
        start_date: date,
        end_date: date,
        budget: int,
        styles: List[TravelStyle],
        places_info: Dict[str, List[Dict]],
        exchange_info: Dict[str, Any],
    ) -> List[DailyPlan]:
        """AI를 사용하여 일별 일정 생성."""
        num_days = (end_date - start_date).days + 1
        style_names = [s.value for s in styles]

        # 수집된 장소 정보를 텍스트로 변환
        places_text = ""
        for style, places in places_info.items():
            if places:
                places_text += f"\n\n### {style} 장소:\n"
                for p in places[:5]:
                    places_text += f"- {p['name']}: {p.get('address', '')}, 평점: {p.get('rating', 'N/A')}\n"
                    places_text += f"  좌표: ({p['location']['lat']}, {p['location']['lng']})\n"

        user_prompt = f"""다음 정보로 {num_days}일 여행 일정을 생성해주세요.

## 여행 정보
- 목적지: {destination}
- 기간: {start_date} ~ {end_date} ({num_days}일)
- 1인 예산: {budget:,}원 (KRW)
- 환율: 1 KRW = {exchange_info['rate']} {exchange_info['to_currency']}
- 여행 스타일: {', '.join(style_names)}

## 수집된 장소 정보
{places_text}

## 요청사항
1. 각 날짜별로 4-6개의 일정을 생성
2. 효율적인 동선 고려
3. 예산 내에서 현실적인 비용 산정
4. 식사 시간 포함 (아침, 점심, 저녁)
5. 각 장소의 실제 좌표 포함

다음 JSON 형식으로 응답해주세요:
{{
  "daily_plans": [
    {{
      "day": 1,
      "date": "2026-03-01",
      "theme": "도심 탐방",
      "schedules": [
        {{
          "order": 1,
          "time": "10:00",
          "place": "장소명",
          "category": "sightseeing",
          "duration_min": 90,
          "estimated_cost": 15000,
          "description": "장소 설명",
          "location": {{"lat": 34.6687, "lng": 135.5065}}
        }}
      ]
    }}
  ]
}}"""

        # Tool handlers 정의
        tool_handlers = {
            "search_places": places_tool.search_places,
            "get_place_details": places_tool.get_place_details,
            "get_exchange_rate": exchange_tool.get_exchange_rate,
        }

        if openai_service.is_available():
            try:
                response = await openai_service.execute_with_tools(
                    messages=[
                        {"role": "system", "content": self.system_prompt},
                        {"role": "user", "content": user_prompt},
                    ],
                    tools=TRAVEL_PLANNER_TOOLS,
                    tool_handlers=tool_handlers,
                    max_iterations=3,
                )

                # JSON 파싱
                content = response["content"]
                daily_plans = self._parse_daily_plans(content, start_date)

                if daily_plans:
                    return daily_plans

            except Exception as e:
                logger.error(f"OpenAI plan generation failed: {e}")

        # Fallback: Mock 일정 생성
        logger.warning("Using fallback mock plan generation")
        return self._generate_mock_plans(
            destination, start_date, end_date, budget, styles, places_info
        )

    def _parse_daily_plans(
        self,
        content: str,
        start_date: date,
    ) -> List[DailyPlan]:
        """AI 응답에서 일정 파싱."""
        try:
            # JSON 부분 추출
            json_start = content.find("{")
            json_end = content.rfind("}") + 1

            if json_start == -1 or json_end == 0:
                logger.warning("No JSON found in response")
                return []

            json_str = content[json_start:json_end]
            data = json.loads(json_str)

            daily_plans = []
            for plan_data in data.get("daily_plans", []):
                schedules = []
                for sched_data in plan_data.get("schedules", []):
                    try:
                        schedule = Schedule(
                            order=sched_data["order"],
                            time=sched_data["time"],
                            place=sched_data["place"],
                            category=PlaceCategory(sched_data["category"]),
                            duration_min=sched_data["duration_min"],
                            estimated_cost=sched_data.get("estimated_cost", 0),
                            description=sched_data.get("description", ""),
                            location=Location(
                                lat=sched_data["location"]["lat"],
                                lng=sched_data["location"]["lng"],
                            ),
                        )
                        schedules.append(schedule)
                    except Exception as e:
                        logger.warning(f"Failed to parse schedule: {e}")

                if schedules:
                    plan_date = datetime.strptime(
                        plan_data["date"], "%Y-%m-%d"
                    ).date() if "date" in plan_data else start_date + timedelta(days=plan_data["day"] - 1)

                    daily_plan = DailyPlan(
                        day=plan_data["day"],
                        date=plan_date,
                        theme=plan_data.get("theme", ""),
                        schedules=schedules,
                    )
                    daily_plans.append(daily_plan)

            return daily_plans

        except json.JSONDecodeError as e:
            logger.error(f"JSON parse error: {e}")
            return []

    def _generate_mock_plans(
        self,
        destination: str,
        start_date: date,
        end_date: date,
        budget: int,
        styles: List[TravelStyle],
        places_info: Dict[str, List[Dict]],
    ) -> List[DailyPlan]:
        """Mock 일정 생성 (API 실패 시 대체)."""
        num_days = (end_date - start_date).days + 1
        daily_budget = budget // num_days

        # 목적지별 기본 좌표
        base_coords = {
            "오사카": (34.6937, 135.5023),
            "도쿄": (35.6762, 139.6503),
            "교토": (35.0116, 135.7681),
            "방콕": (13.7563, 100.5018),
            "파리": (48.8566, 2.3522),
        }

        base_lat, base_lng = base_coords.get(destination, (35.6762, 139.6503))

        daily_plans = []
        themes = [
            f"{destination} 도심 탐방",
            f"{destination} 문화 체험",
            f"{destination} 미식 투어",
            f"{destination} 쇼핑 & 휴식",
        ]

        for day in range(num_days):
            current_date = start_date + timedelta(days=day)
            theme = themes[day % len(themes)]

            schedules = [
                Schedule(
                    order=1,
                    time="09:30",
                    place=f"{destination} 아침 식사",
                    category=PlaceCategory.FOOD,
                    duration_min=60,
                    estimated_cost=int(daily_budget * 0.1),
                    description="현지 조식 맛집",
                    location=Location(lat=base_lat + 0.001, lng=base_lng + 0.001),
                ),
                Schedule(
                    order=2,
                    time="11:00",
                    place=f"{destination} 명소 {day + 1}",
                    category=PlaceCategory.SIGHTSEEING,
                    duration_min=120,
                    estimated_cost=int(daily_budget * 0.15),
                    description="인기 관광지",
                    location=Location(lat=base_lat + 0.003, lng=base_lng + 0.002),
                ),
                Schedule(
                    order=3,
                    time="13:30",
                    place=f"{destination} 점심 맛집",
                    category=PlaceCategory.FOOD,
                    duration_min=90,
                    estimated_cost=int(daily_budget * 0.2),
                    description="현지 인기 음식점",
                    location=Location(lat=base_lat + 0.004, lng=base_lng + 0.003),
                ),
                Schedule(
                    order=4,
                    time="15:30",
                    place=f"{destination} 체험 {day + 1}",
                    category=PlaceCategory.ACTIVITY,
                    duration_min=120,
                    estimated_cost=int(daily_budget * 0.25),
                    description="현지 문화 체험",
                    location=Location(lat=base_lat + 0.005, lng=base_lng + 0.004),
                ),
                Schedule(
                    order=5,
                    time="18:00",
                    place=f"{destination} 저녁 식사",
                    category=PlaceCategory.FOOD,
                    duration_min=120,
                    estimated_cost=int(daily_budget * 0.3),
                    description="저녁 맛집",
                    location=Location(lat=base_lat + 0.002, lng=base_lng + 0.005),
                ),
            ]

            daily_plans.append(DailyPlan(
                day=day + 1,
                date=current_date,
                theme=theme,
                schedules=schedules,
            ))

        return daily_plans


# Singleton instance
travel_planner_agent = TravelPlannerAgent()
