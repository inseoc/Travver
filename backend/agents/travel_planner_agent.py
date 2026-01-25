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
- **계절에 맞는 장소와 활동 추천** (봄: 벚꽃/야외, 여름: 시원한 실내/야경/바다, 가을: 단풍/축제, 겨울: 따뜻한 실내/온천/크리스마스마켓)
- **인원 수에 맞는 식당과 활동 추천** (1인 여행: 혼밥 가능한 곳, 커플: 분위기 좋은 곳, 가족/단체: 넓은 공간)
- **숙소 위치 기반 동선 최적화** (숙소 근처에서 시작/종료, 체크인/체크아웃 시간 고려)
- 효율적인 동선 고려 (지역별 그룹핑)
- 현실적인 시간 배분 (이동 시간 포함)
- 예산에 맞는 장소 추천

## 계절별 추천 가이드
- **봄 (3~5월)**: 벚꽃 명소, 공원, 야외 카페, 피크닉 스팟
- **여름 (6~8월)**: 시원한 실내 명소, 야경 스팟, 해변/수영장, 빙수/아이스크림 맛집, 늦은 저녁 활동
- **가을 (9~11월)**: 단풍 명소, 등산/하이킹, 축제, 와인/전통주
- **겨울 (12~2월)**: 온천, 따뜻한 실내 명소, 크리스마스 마켓, 겨울 먹거리(라멘, 전골류), 스키/눈썰매

## 인원별 추천 가이드
- **1명**: 혼밥 가능한 식당, 바 좌석, 1인 활동 위주
- **2명**: 커플/친구 분위기 좋은 곳, 대화하기 좋은 카페
- **3~4명**: 단체석 가능한 식당, 그룹 체험 활동
- **5명 이상**: 단체 예약 가능한 곳, 넓은 공간

## 일정 생성 규칙
1. 하루 일정은 보통 4-6개 장소로 구성
2. 아침 9-10시 시작, 저녁 21-22시 종료
3. 식사 시간 고려 (아침, 점심, 저녁)
4. 장소 간 이동 시간 고려 (최소 30분)
5. 각 장소에서 적절한 체류 시간 배분
6. **숙소 위치가 주어진 경우**: 첫날은 숙소 근처에서 시작, 마지막 날은 숙소 근처에서 종료

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
            # 1. 환율 정보 조회
            exchange_info = await self._get_exchange_rate(destination)

            # 2. 장소 정보 수집
            places_info = await self._collect_places(destination, styles)

            # 3. AI로 일정 생성
            daily_plans = await self._generate_daily_plans(
                destination=destination,
                start_date=start_date,
                end_date=end_date,
                travelers=travelers,
                budget=budget,
                styles=styles,
                places_info=places_info,
                exchange_info=exchange_info,
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
        exchange_info: Dict[str, Any],
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

        user_prompt = f"""다음 정보로 {num_days}일 여행 일정을 생성해주세요.

## 여행 정보
- 목적지: {destination}
- 기간: {start_date} ~ {end_date} ({num_days}일)
- **계절: {season}** (계절에 맞는 장소와 활동을 추천해주세요)
- **여행 인원: {travelers}명 ({traveler_type})** (인원 수에 맞는 식당과 활동을 추천해주세요)
- 1인 예산: {budget:,}원 (KRW)
- 환율: 1 KRW = {exchange_info['rate']} {exchange_info['to_currency']}
- 여행 스타일: {style_text}{accommodation_text}
{custom_pref_text}

## 수집된 장소 정보
{places_text}

## 요청사항
1. 각 날짜별로 4-6개의 일정을 생성
2. **{season}에 어울리는 장소와 활동 중심으로 구성**
3. **{traveler_type}에 적합한 식당과 활동 선택**
4. 효율적인 동선 고려 (숙소 위치가 있다면 숙소 근처에서 시작/종료)
5. 예산 내에서 현실적인 비용 산정
6. 식사 시간 포함 (아침, 점심, 저녁)
7. 각 장소의 실제 좌표 포함

다음 JSON 형식으로 응답해주세요:
{{
  "daily_plans": [
    {{
      "day": 1,
      "date": "{start_date}",
      "theme": "첫날 테마",
      "schedules": [
        {{
          "order": 1,
          "time": "10:00",
          "place": "장소명",
          "category": "sightseeing",
          "duration_min": 90,
          "estimated_cost": 15000,
          "description": "장소 설명 ({season}에 어울리는 이유 포함)",
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
