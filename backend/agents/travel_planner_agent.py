"""Travel Planner Agent - AI 기반 여행 일정 생성."""

import asyncio
import json
import re
import uuid
from datetime import date, datetime, timedelta
from typing import Any, Dict, List, Optional

from core.logger import logger
from core.exceptions import AIServiceException
from services.openai_service import openai_service
from tools import places_tool
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
        return """전문 여행 플래너 AI. 최적의 여행 일정을 JSON으로 생성.

규칙:
- 하루 4-6개 장소, 09~22시, 식사 3끼 포함
- 장소 간 이동 30분 이내, 동선 최적화 (지역별 그룹핑)
- 장소 중복 금지 (전체 여행 기간 동안)
- 반드시 실제 존재하는 구체적 장소명 사용 (일반 명칭 금지)
- 수집된 장소 정보의 실제 장소명과 좌표 우선 사용
- 계절/인원에 맞는 장소 추천
- 숙소가 주어지면 그 근처에서 일정 시작/종료

카테고리: food, sightseeing, accommodation, activity, shopping, rest

출력 형식 (반드시 준수):
- time: 시작 시간만 "HH:MM" 형식 (예: "09:00", "13:30"). 시간 범위("09:00-10:40") 금지.
- duration_min: 소요 시간은 별도 필드로 분 단위 정수 제공.

출력: JSON {daily_plans: [{day, date, theme, schedules: [{order, time, place, category, duration_min, estimated_cost, description, location: {lat, lng}}]}]}"""

    async def generate_plan(
        self,
        destination: str,
        start_date: date,
        end_date: date,
        travelers: int,
        budget: int,
        styles: List[TravelStyle],
        accommodation_location: Optional[str] = None,
        custom_preference: Optional[str] = None,
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
            accommodation_location: 숙소 위치 (선택)
            custom_preference: 사용자 커스텀 선호도 (선택)

        Returns:
            생성된 Trip 객체
        """
        logger.info(f"Generating travel plan: {destination}, {start_date} - {end_date}")

        try:
            # 1. 장소 정보 수집
            places_info = await self._collect_places(destination, styles)

            # 2. AI로 일정 생성
            daily_plans = await self._generate_daily_plans(
                destination=destination,
                start_date=start_date,
                end_date=end_date,
                travelers=travelers,
                budget=budget,
                styles=styles,
                places_info=places_info,
                accommodation_location=accommodation_location,
                custom_preference=custom_preference,
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

    async def _collect_places(
        self,
        destination: str,
        styles: List[TravelStyle],
    ) -> Dict[str, List[Dict]]:
        """여행 스타일에 맞는 장소 정보 수집 (병렬 처리)."""
        # 스타일별 대표 검색 키워드 (1개로 축소하여 속도 향상)
        style_queries = {
            TravelStyle.FOOD: "맛집",
            TravelStyle.SIGHTSEEING: "관광지",
            TravelStyle.RELAXATION: "온천",
            TravelStyle.ACTIVITY: "액티비티",
            TravelStyle.SHOPPING: "쇼핑",
            TravelStyle.PHOTO: "포토스팟",
        }

        async def search_for_style(style: TravelStyle) -> tuple:
            """단일 스타일에 대한 검색 수행."""
            query = style_queries.get(style, style.value)
            try:
                results = await places_tool.search_places(
                    query=query,
                    location=destination,
                    max_results=5,
                )
                return (style.value, results)
            except Exception as e:
                logger.warning(f"Failed to search places for {query}: {e}")
                return (style.value, [])

        # 모든 스타일에 대해 병렬로 검색 실행
        tasks = [search_for_style(style) for style in styles]
        results = await asyncio.gather(*tasks)

        # 결과를 딕셔너리로 변환
        places_info = {style: places for style, places in results}

        return places_info

    def _get_season(self, month: int) -> str:
        """월에 따른 계절 반환."""
        if month in [3, 4, 5]:
            return "봄"
        elif month in [6, 7, 8]:
            return "여름"
        elif month in [9, 10, 11]:
            return "가을"
        else:
            return "겨울"

    def _get_traveler_type(self, travelers: int) -> str:
        """인원 수에 따른 여행 타입 반환."""
        if travelers == 1:
            return "1인 여행 (혼행)"
        elif travelers == 2:
            return "2인 여행 (커플/친구)"
        elif travelers <= 4:
            return f"{travelers}인 소그룹 여행"
        else:
            return f"{travelers}인 단체 여행"

    async def _generate_daily_plans(
        self,
        destination: str,
        start_date: date,
        end_date: date,
        travelers: int,
        budget: int,
        styles: List[TravelStyle],
        places_info: Dict[str, List[Dict]],
        accommodation_location: Optional[str] = None,
        custom_preference: Optional[str] = None,
    ) -> List[DailyPlan]:
        """AI를 사용하여 일별 일정 생성."""
        num_days = (end_date - start_date).days + 1
        style_names = [s.value for s in styles]

        # 계절 및 여행 타입 정보
        season = self._get_season(start_date.month)
        traveler_type = self._get_traveler_type(travelers)

        # 수집된 장소 정보를 텍스트로 변환
        places_text = ""
        for style, places in places_info.items():
            if places:
                places_text += f"\n\n### {style} 장소:\n"
                for p in places[:5]:
                    places_text += f"- {p['name']}: {p.get('address', '')}, 평점: {p.get('rating', 'N/A')}\n"
                    places_text += f"  좌표: ({p['location']['lat']}, {p['location']['lng']})\n"

        # 숙소 위치 정보
        accommodation_text = ""
        if accommodation_location:
            accommodation_text = f"\n- 숙소 위치: {accommodation_location} (이 근처에서 일정 시작/종료 권장)"

        # 커스텀 선호도 정보
        custom_pref_text = ""
        if custom_preference:
            custom_pref_text = f"\n\n## 사용자 특별 요청\n{custom_preference}"

        # 스타일이 없을 경우 기본값
        style_text = ', '.join(style_names) if style_names else "일반 관광"

        user_prompt = f"""{destination} {num_days}일 여행 일정 생성.

목적지: {destination}, 기간: {start_date}~{end_date}, 계절: {season}
인원: {travelers}명 ({traveler_type}), 1인 예산: {budget:,}원, 스타일: {style_text}{accommodation_text}
{custom_pref_text}

## 수집된 장소 정보
{places_text}

시작일: {start_date}. 장소 중복 금지. 동선 최적화. 실제 장소명+좌표 필수."""

        # 이미 장소 정보가 수집되어 있으므로 tool calling 없이 직접 생성
        # 이렇게 하면 API 호출이 1회로 줄어들어 속도가 크게 향상됨
        if openai_service.is_available():
            try:
                response = await openai_service.chat_completion(
                    messages=[
                        {"role": "system", "content": self.system_prompt},
                        {"role": "user", "content": user_prompt},
                    ],
                    tools=None,  # tool calling 비활성화 - 이미 장소 정보 수집됨

                    response_format={"type": "json_object"},
                )

                # JSON 파싱
                content = response["content"]
                logger.debug(f"AI response content length: {len(content) if content else 0}")

                if not content:
                    logger.warning("AI response content is empty or None")
                else:
                    daily_plans = self._parse_daily_plans(content, start_date)

                    if daily_plans:
                        return daily_plans
                    else:
                        logger.warning("Failed to parse daily plans from AI response")

            except Exception as e:
                logger.error(f"OpenAI plan generation failed: {e}")

        # Fallback: Mock 일정 생성
        logger.warning("Using fallback mock plan generation")
        return self._generate_mock_plans(
            destination, start_date, end_date, budget, styles, places_info
        )

    def _extract_json_from_response(self, content: str) -> Optional[str]:
        """AI 응답에서 JSON 문자열 추출."""
        if not content:
            return None

        # 1. 마크다운 코드 블록에서 JSON 추출 (```json ... ``` 또는 ``` ... ```)
        code_block_pattern = r'```(?:json)?\s*([\s\S]*?)```'
        matches = re.findall(code_block_pattern, content)

        for match in matches:
            match = match.strip()
            if match.startswith("{") and match.endswith("}"):
                return match

        # 2. 순수 JSON 형태로 응답한 경우 (코드 블록 없이)
        json_start = content.find("{")
        json_end = content.rfind("}") + 1

        if json_start != -1 and json_end > json_start:
            return content[json_start:json_end]

        return None

    def _parse_daily_plans(
        self,
        content: str,
        start_date: date,
    ) -> List[DailyPlan]:
        """AI 응답에서 일정 파싱."""
        try:
            # JSON 부분 추출
            json_str = self._extract_json_from_response(content)

            if not json_str:
                logger.warning("No JSON found in response")
                logger.debug(f"Response content: {content[:500] if content else 'None'}...")
                return []

            data = json.loads(json_str)

            daily_plans = []
            for plan_data in data.get("daily_plans", []):
                schedules = []
                for sched_data in plan_data.get("schedules", []):
                    try:
                        # AI가 "09:00-10:40" 같은 시간 범위를 반환할 수 있으므로
                        # 시작 시간만 추출 (HH:MM)
                        raw_time = str(sched_data.get("time", ""))
                        if "-" in raw_time:
                            raw_time = raw_time.split("-")[0].strip()
                        # "09:00" 형태가 아닌 경우 정규화
                        time_match = re.match(r"(\d{1,2}):(\d{2})", raw_time)
                        if time_match:
                            raw_time = f"{int(time_match.group(1)):02d}:{time_match.group(2)}"

                        schedule = Schedule(
                            order=sched_data["order"],
                            time=raw_time,
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

    def _get_real_places(self, destination: str) -> Dict[str, List[Dict]]:
        """목적지별 실제 장소 데이터."""
        places_db = {
            "오사카": {
                "themes": ["도톤보리 & 난바 탐방", "오사카성 & 역사 투어", "신세카이 & 로컬 맛집", "우메다 & 쇼핑"],
                "breakfast": [
                    {"name": "이치란 라멘 도톤보리점", "desc": "24시간 운영 돈코츠 라멘 본점", "lat": 34.6687, "lng": 135.5013},
                    {"name": "마루카메 제면 난바점", "desc": "갓 뽑은 사누키 우동 전문점", "lat": 34.6654, "lng": 135.5014},
                    {"name": "에그슬럿 오사카", "desc": "LA 감성 에그 샌드위치 브런치", "lat": 34.7025, "lng": 135.4959},
                    {"name": "하드락 카페 오사카", "desc": "미국식 아침 세트 메뉴", "lat": 34.6686, "lng": 135.4299},
                ],
                "sightseeing": [
                    {"name": "오사카성 천수각", "desc": "도요토미 히데요시가 세운 일본 3대 성곽", "lat": 34.6873, "lng": 135.5262},
                    {"name": "도톤보리 글리코상", "desc": "오사카의 상징적인 네온사인 거리", "lat": 34.6687, "lng": 135.5010},
                    {"name": "츠텐카쿠 전망대", "desc": "신세카이의 랜드마크 타워", "lat": 34.6525, "lng": 135.5063},
                    {"name": "우메다 스카이빌딩 공중정원", "desc": "173m 높이 360도 파노라마 전망", "lat": 34.7052, "lng": 135.4906},
                ],
                "lunch": [
                    {"name": "쿠라스시 도톤보리점", "desc": "회전초밥 체인, 100엔 스시", "lat": 34.6690, "lng": 135.5025},
                    {"name": "하루카스 다이닝", "desc": "아베노 하루카스 레스토랑가", "lat": 34.6463, "lng": 135.5138},
                    {"name": "치보 본점", "desc": "오코노미야키 명가, 70년 전통", "lat": 34.6685, "lng": 135.5013},
                    {"name": "키지 본점", "desc": "철판 오코노미야키의 성지", "lat": 34.7048, "lng": 135.4948},
                ],
                "activity": [
                    {"name": "유니버설 스튜디오 재팬", "desc": "해리포터, 슈퍼닌텐도월드 테마파크", "lat": 34.6654, "lng": 135.4323},
                    {"name": "신세카이 쟝쟝요코초", "desc": "레트로 골목 탐방 & 꼬치튀김 체험", "lat": 34.6520, "lng": 135.5060},
                    {"name": "구로몬 시장", "desc": "오사카의 부엌, 신선한 해산물 시식", "lat": 34.6668, "lng": 135.5069},
                    {"name": "덴덴타운", "desc": "오사카의 아키하바라, 전자상가 & 서브컬처", "lat": 34.6598, "lng": 135.5056},
                ],
                "dinner": [
                    {"name": "칸자키 갓텐 스시", "desc": "신선한 스시 오마카세", "lat": 34.6977, "lng": 135.4912},
                    {"name": "다루마 신세카이 본점", "desc": "쿠시카츠(꼬치튀김) 원조 맛집", "lat": 34.6522, "lng": 135.5059},
                    {"name": "아지노야 본점", "desc": "타코야키 원조 맛집, 18개입", "lat": 34.6525, "lng": 135.5065},
                    {"name": "마츠리야", "desc": "야키니쿠 무한리필 전문점", "lat": 34.7005, "lng": 135.4973},
                ],
            },
            "제주도": {
                "themes": ["제주시 & 동문시장 탐방", "성산일출봉 & 동부 투어", "서귀포 & 중문 관광", "애월 & 서부 카페 투어"],
                "breakfast": [
                    {"name": "올래국수", "desc": "제주 고기국수 맛집, 줄서는 식당", "lat": 33.5121, "lng": 126.5232},
                    {"name": "삼대국수회관", "desc": "3대째 이어온 고기국수 명가", "lat": 33.4996, "lng": 126.5287},
                    {"name": "우진해장국", "desc": "제주 현지인 아침 해장 맛집", "lat": 33.4912, "lng": 126.4935},
                    {"name": "명진전복 본점", "desc": "전복죽, 전복돌솥밥 전문점", "lat": 33.5025, "lng": 126.5412},
                ],
                "sightseeing": [
                    {"name": "성산일출봉", "desc": "유네스코 세계자연유산, 해돋이 명소", "lat": 33.4587, "lng": 126.9425},
                    {"name": "만장굴", "desc": "세계 최장 용암동굴, 천연기념물", "lat": 33.5282, "lng": 126.7712},
                    {"name": "천지연폭포", "desc": "서귀포 대표 폭포, 야간 조명", "lat": 33.2469, "lng": 126.5548},
                    {"name": "한라산 어리목 코스", "desc": "제주 최고봉 트레킹", "lat": 33.3617, "lng": 126.4969},
                ],
                "lunch": [
                    {"name": "제주김만복 본점", "desc": "전복김밥, 성게김밥 원조", "lat": 33.5012, "lng": 126.5287},
                    {"name": "돈사돈 본점", "desc": "제주 흑돼지 구이 맛집", "lat": 33.4856, "lng": 126.4923},
                    {"name": "미영이네 식당", "desc": "갈치조림, 옥돔구이 현지 맛집", "lat": 33.2512, "lng": 126.5612},
                    {"name": "자매국수", "desc": "제주 비빔국수, 고기국수 맛집", "lat": 33.2469, "lng": 126.5023},
                ],
                "activity": [
                    {"name": "섭지코지", "desc": "드라마 촬영지, 해안 절경 산책로", "lat": 33.4240, "lng": 126.9296},
                    {"name": "우도", "desc": "소가 누운 모양의 아름다운 섬", "lat": 33.5063, "lng": 126.9520},
                    {"name": "카멜리아힐", "desc": "동양 최대 동백꽃 수목원", "lat": 33.2898, "lng": 126.3689},
                    {"name": "아쿠아플라넷 제주", "desc": "아시아 최대 규모 아쿠아리움", "lat": 33.4337, "lng": 126.9269},
                ],
                "dinner": [
                    {"name": "흑돼지거리 돈사돈", "desc": "제주 흑돼지 숯불구이", "lat": 33.4856, "lng": 126.4923},
                    {"name": "광해회국수", "desc": "전복, 소라, 성게 해산물 국수", "lat": 33.4687, "lng": 126.9165},
                    {"name": "제주 동문시장 야시장", "desc": "현지 먹거리 투어, 흑돼지꼬치", "lat": 33.5125, "lng": 126.5260},
                    {"name": "오는정김밥", "desc": "한치물회, 성게비빔밥 맛집", "lat": 33.2512, "lng": 126.5123},
                ],
            },
        }
        return places_db.get(destination, places_db["오사카"])

    def _generate_mock_plans(
        self,
        destination: str,
        start_date: date,
        end_date: date,
        budget: int,
        styles: List[TravelStyle],
        places_info: Dict[str, List[Dict]],
    ) -> List[DailyPlan]:
        """Mock 일정 생성 (API 실패 시 대체) - 실제 장소명 사용."""
        num_days = (end_date - start_date).days + 1
        daily_budget = budget // num_days if num_days > 0 else budget

        # 실제 장소 데이터 가져오기
        places = self._get_real_places(destination)
        themes = places.get("themes", [f"{destination} 탐방"])

        daily_plans = []

        for day in range(num_days):
            current_date = start_date + timedelta(days=day)
            theme = themes[day % len(themes)]

            # 각 카테고리에서 해당 날짜에 맞는 장소 선택
            breakfast = places["breakfast"][day % len(places["breakfast"])]
            sightseeing = places["sightseeing"][day % len(places["sightseeing"])]
            lunch = places["lunch"][day % len(places["lunch"])]
            activity = places["activity"][day % len(places["activity"])]
            dinner = places["dinner"][day % len(places["dinner"])]

            schedules = [
                Schedule(
                    order=1,
                    time="09:30",
                    place=breakfast["name"],
                    category=PlaceCategory.FOOD,
                    duration_min=60,
                    estimated_cost=int(daily_budget * 0.1),
                    description=breakfast["desc"],
                    location=Location(lat=breakfast["lat"], lng=breakfast["lng"]),
                ),
                Schedule(
                    order=2,
                    time="11:00",
                    place=sightseeing["name"],
                    category=PlaceCategory.SIGHTSEEING,
                    duration_min=120,
                    estimated_cost=int(daily_budget * 0.15),
                    description=sightseeing["desc"],
                    location=Location(lat=sightseeing["lat"], lng=sightseeing["lng"]),
                ),
                Schedule(
                    order=3,
                    time="13:30",
                    place=lunch["name"],
                    category=PlaceCategory.FOOD,
                    duration_min=90,
                    estimated_cost=int(daily_budget * 0.2),
                    description=lunch["desc"],
                    location=Location(lat=lunch["lat"], lng=lunch["lng"]),
                ),
                Schedule(
                    order=4,
                    time="15:30",
                    place=activity["name"],
                    category=PlaceCategory.ACTIVITY,
                    duration_min=120,
                    estimated_cost=int(daily_budget * 0.25),
                    description=activity["desc"],
                    location=Location(lat=activity["lat"], lng=activity["lng"]),
                ),
                Schedule(
                    order=5,
                    time="18:00",
                    place=dinner["name"],
                    category=PlaceCategory.FOOD,
                    duration_min=120,
                    estimated_cost=int(daily_budget * 0.3),
                    description=dinner["desc"],
                    location=Location(lat=dinner["lat"], lng=dinner["lng"]),
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
