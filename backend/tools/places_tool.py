"""Google Places API tool for location search."""

from typing import Any, Dict, List, Optional
import httpx
from tenacity import retry, stop_after_attempt, wait_exponential

from core.config import settings
from core.logger import logger
from core.exceptions import ToolExecutionException


class PlacesTool:
    """Google Places API를 사용한 장소 검색 도구."""

    def __init__(self):
        """Initialize Places tool."""
        self.api_key = settings.google_places_api_key
        self.base_url = "https://maps.googleapis.com/maps/api/place"
        self._geocode_cache: Dict[str, tuple] = {}
        self._http_client: Optional[httpx.AsyncClient] = None

    def _get_client(self) -> httpx.AsyncClient:
        """Get or create reusable HTTP client."""
        if self._http_client is None or self._http_client.is_closed:
            self._http_client = httpx.AsyncClient(timeout=10.0)
        return self._http_client

    async def _geocode(self, location: str) -> Optional[tuple]:
        """Geocode a location with caching."""
        if location in self._geocode_cache:
            return self._geocode_cache[location]

        geocode_url = "https://maps.googleapis.com/maps/api/geocode/json"
        client = self._get_client()
        geo_response = await client.get(
            geocode_url,
            params={"address": location, "key": self.api_key},
        )
        geo_data = geo_response.json()

        if geo_data.get("status") != "OK" or not geo_data.get("results"):
            return None

        lat = geo_data["results"][0]["geometry"]["location"]["lat"]
        lng = geo_data["results"][0]["geometry"]["location"]["lng"]
        self._geocode_cache[location] = (lat, lng)
        return (lat, lng)

    def is_available(self) -> bool:
        """Check if tool is available."""
        return bool(self.api_key)

    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=1, max=5),
    )
    async def search_places(
        self,
        query: str,
        location: str,
        place_type: Optional[str] = None,
        max_results: int = 5,
        radius_km: float = 5.0,
    ) -> List[Dict[str, Any]]:
        """
        장소를 검색합니다.

        Args:
            query: 검색 키워드
            location: 검색 지역
            place_type: 장소 유형
            max_results: 최대 결과 수
            radius_km: 검색 반경 (km)

        Returns:
            검색된 장소 목록
        """
        if not self.is_available():
            logger.warning("Places API not configured, using mock data")
            return self._get_mock_places(query, location, max_results)

        try:
            # 먼저 지역의 좌표를 가져옴 (캐시 활용)
            coords = await self._geocode(location)
            if not coords:
                logger.warning(f"Geocoding failed for: {location}")
                return self._get_mock_places(query, location, max_results)

            lat, lng = coords
            client = self._get_client()

            # Text Search API 호출
            search_url = f"{self.base_url}/textsearch/json"
            params = {
                "query": f"{query} in {location}",
                "location": f"{lat},{lng}",
                "radius": int(radius_km * 1000),
                "key": self.api_key,
                "language": "ko",
            }

            if place_type:
                params["type"] = place_type

            response = await client.get(search_url, params=params)
            data = response.json()

            if data.get("status") != "OK":
                logger.warning(f"Places search failed: {data.get('status')}")
                return self._get_mock_places(query, location, max_results)

            results = []
            for place in data.get("results", [])[:max_results]:
                results.append({
                    "place_id": place.get("place_id"),
                    "name": place.get("name"),
                    "address": place.get("formatted_address"),
                    "location": {
                        "lat": place["geometry"]["location"]["lat"],
                        "lng": place["geometry"]["location"]["lng"],
                    },
                    "rating": place.get("rating"),
                    "user_ratings_total": place.get("user_ratings_total"),
                    "types": place.get("types", []),
                    "price_level": place.get("price_level"),
                    "open_now": place.get("opening_hours", {}).get("open_now"),
                })

            logger.info(f"Found {len(results)} places for '{query}' in {location}")
            return results

        except Exception as e:
            logger.error(f"Places search error: {e}")
            return self._get_mock_places(query, location, max_results)

    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=1, max=5),
    )
    async def get_place_details(
        self,
        place_name: str,
        location: str,
        place_id: Optional[str] = None,
    ) -> Dict[str, Any]:
        """
        장소 상세 정보를 조회합니다.

        Args:
            place_name: 장소명
            location: 지역
            place_id: Google Places ID (있으면 사용)

        Returns:
            장소 상세 정보
        """
        if not self.is_available():
            logger.warning("Places API not configured, using mock data")
            return self._get_mock_place_details(place_name, location)

        try:
            # place_id가 없으면 검색해서 가져옴
            if not place_id:
                places = await self.search_places(place_name, location, max_results=1)
                if places:
                    place_id = places[0].get("place_id")

            if not place_id:
                return self._get_mock_place_details(place_name, location)

            client = self._get_client()

            # Place Details API 호출
            details_url = f"{self.base_url}/details/json"
            params = {
                "place_id": place_id,
                "key": self.api_key,
                "language": "ko",
                "fields": "name,formatted_address,geometry,rating,user_ratings_total,"
                         "opening_hours,price_level,website,formatted_phone_number,"
                         "reviews,types,photos",
            }

            response = await client.get(details_url, params=params)
            data = response.json()

            if data.get("status") != "OK":
                return self._get_mock_place_details(place_name, location)

            result = data.get("result", {})
            return {
                "place_id": place_id,
                "name": result.get("name"),
                "address": result.get("formatted_address"),
                "location": {
                    "lat": result.get("geometry", {}).get("location", {}).get("lat"),
                    "lng": result.get("geometry", {}).get("location", {}).get("lng"),
                },
                "rating": result.get("rating"),
                "user_ratings_total": result.get("user_ratings_total"),
                "price_level": result.get("price_level"),
                "opening_hours": result.get("opening_hours", {}).get("weekday_text", []),
                "website": result.get("website"),
                "phone": result.get("formatted_phone_number"),
                "types": result.get("types", []),
                "reviews": [
                    {
                        "rating": r.get("rating"),
                        "text": r.get("text"),
                        "time": r.get("relative_time_description"),
                    }
                    for r in result.get("reviews", [])[:3]
                ],
            }

        except Exception as e:
            logger.error(f"Place details error: {e}")
            return self._get_mock_place_details(place_name, location)

    def _get_mock_places(
        self,
        query: str,
        location: str,
        max_results: int,
    ) -> List[Dict[str, Any]]:
        """Mock 장소 데이터 생성 - 실제 장소명 사용."""
        # 지역별 실제 장소 데이터베이스
        real_places_db = {
            "오사카": {
                "맛집": [
                    {"name": "이치란 라멘 도톤보리점", "address": "오사카시 중앙구 도톤보리 1-4-16", "lat": 34.6687, "lng": 135.5013, "rating": 4.4},
                    {"name": "쿠라스시 도톤보리점", "address": "오사카시 중앙구 도톤보리 1-8-22", "lat": 34.6690, "lng": 135.5025, "rating": 4.3},
                    {"name": "치보 본점", "address": "오사카시 중앙구 도톤보리 1-5-5", "lat": 34.6685, "lng": 135.5013, "rating": 4.2},
                    {"name": "다루마 신세카이 본점", "address": "오사카시 나니와구 에비스히가시 3-3-4", "lat": 34.6522, "lng": 135.5059, "rating": 4.5},
                    {"name": "아지노야 본점", "address": "오사카시 나니와구 에비스히가시 1-18-18", "lat": 34.6525, "lng": 135.5065, "rating": 4.3},
                ],
                "레스토랑": [
                    {"name": "키지 우메다 본점", "address": "오사카시 키타구 카쿠다초", "lat": 34.7048, "lng": 135.4948, "rating": 4.4},
                    {"name": "칸자키 갓텐 스시", "address": "오사카시 키타구 우메다 1-3", "lat": 34.6977, "lng": 135.4912, "rating": 4.5},
                    {"name": "마츠리야 우메다점", "address": "오사카시 키타구 우메다 1-9", "lat": 34.7005, "lng": 135.4973, "rating": 4.2},
                    {"name": "하루카스 다이닝", "address": "오사카시 아베노구 아베노스지 1-1-43", "lat": 34.6463, "lng": 135.5138, "rating": 4.3},
                    {"name": "마루카메 제면 난바점", "address": "오사카시 중앙구 난바 3-6-14", "lat": 34.6654, "lng": 135.5014, "rating": 4.1},
                ],
                "현지 음식": [
                    {"name": "구로몬 시장", "address": "오사카시 중앙구 닛폰바시 2-4-1", "lat": 34.6668, "lng": 135.5069, "rating": 4.4},
                    {"name": "신세카이 쟝쟝요코초", "address": "오사카시 나니와구 에비스히가시 3", "lat": 34.6520, "lng": 135.5060, "rating": 4.3},
                    {"name": "도톤보리 타코야키 골목", "address": "오사카시 중앙구 도톤보리 1-9", "lat": 34.6688, "lng": 135.5015, "rating": 4.2},
                    {"name": "텐진바시스지 상점가", "address": "오사카시 키타구 텐진바시 4-9", "lat": 34.7065, "lng": 135.5112, "rating": 4.1},
                    {"name": "호젠지 요코초", "address": "오사카시 중앙구 난바 1-2", "lat": 34.6692, "lng": 135.5025, "rating": 4.4},
                ],
                "관광지": [
                    {"name": "오사카성 천수각", "address": "오사카시 중앙구 오사카조 1-1", "lat": 34.6873, "lng": 135.5262, "rating": 4.6},
                    {"name": "도톤보리 글리코상", "address": "오사카시 중앙구 도톤보리 1", "lat": 34.6687, "lng": 135.5010, "rating": 4.5},
                    {"name": "츠텐카쿠 전망대", "address": "오사카시 나니와구 에비스히가시 1-18-6", "lat": 34.6525, "lng": 135.5063, "rating": 4.3},
                    {"name": "우메다 스카이빌딩 공중정원", "address": "오사카시 키타구 오요도나카 1-1-88", "lat": 34.7052, "lng": 135.4906, "rating": 4.5},
                    {"name": "시텐노지", "address": "오사카시 텐노지구 시텐노지 1-11-18", "lat": 34.6533, "lng": 135.5167, "rating": 4.4},
                ],
                "명소": [
                    {"name": "신사이바시스지 상점가", "address": "오사카시 중앙구 신사이바시스지", "lat": 34.6720, "lng": 135.5010, "rating": 4.3},
                    {"name": "난바 파크스", "address": "오사카시 나니와구 난바나카 2-10-70", "lat": 34.6612, "lng": 135.5030, "rating": 4.4},
                    {"name": "덴포잔 대관람차", "address": "오사카시 미나토구 가이간도리 1-1-10", "lat": 34.6544, "lng": 135.4298, "rating": 4.2},
                    {"name": "아베노 하루카스", "address": "오사카시 아베노구 아베노스지 1-1-43", "lat": 34.6463, "lng": 135.5138, "rating": 4.5},
                    {"name": "스미요시타이샤", "address": "오사카시 스미요시구 스미요시 2-9-89", "lat": 34.6127, "lng": 135.4928, "rating": 4.5},
                ],
                "랜드마크": [
                    {"name": "통천각", "address": "오사카시 나니와구 에비스히가시 1-18-6", "lat": 34.6525, "lng": 135.5063, "rating": 4.3},
                    {"name": "오사카 해유관", "address": "오사카시 미나토구 가이간도리 1-1-10", "lat": 34.6545, "lng": 135.4287, "rating": 4.6},
                    {"name": "그랜프론트 오사카", "address": "오사카시 키타구 오후카초 4-1", "lat": 34.7055, "lng": 135.4945, "rating": 4.3},
                    {"name": "난바 그랜드 카이칸", "address": "오사카시 나니와구 난바센니치마에", "lat": 34.6603, "lng": 135.5015, "rating": 4.1},
                    {"name": "오사카역 시티", "address": "오사카시 키타구 우메다 3-1-3", "lat": 34.7024, "lng": 135.4959, "rating": 4.4},
                ],
                "포토스팟": [
                    {"name": "도톤보리 글리코상 포토존", "address": "오사카시 중앙구 도톤보리", "lat": 34.6687, "lng": 135.5010, "rating": 4.5},
                    {"name": "우메다 스카이빌딩 전망대", "address": "오사카시 키타구 오요도나카 1-1-88", "lat": 34.7052, "lng": 135.4906, "rating": 4.5},
                    {"name": "오사카성 니시노마루 정원", "address": "오사카시 중앙구 오사카조 2", "lat": 34.6867, "lng": 135.5230, "rating": 4.4},
                    {"name": "에비스바시", "address": "오사카시 중앙구 에비스바시", "lat": 34.6690, "lng": 135.5015, "rating": 4.3},
                    {"name": "나카노시마 공원", "address": "오사카시 키타구 나카노시마 1", "lat": 34.6915, "lng": 135.5030, "rating": 4.4},
                ],
                "뷰포인트": [
                    {"name": "하루카스 300 전망대", "address": "오사카시 아베노구 아베노스지 1-1-43", "lat": 34.6463, "lng": 135.5138, "rating": 4.5},
                    {"name": "덴포잔 대관람차", "address": "오사카시 미나토구 가이간도리 1-1-10", "lat": 34.6544, "lng": 135.4298, "rating": 4.2},
                    {"name": "사카이스지혼마치 빌딩 전망층", "address": "오사카시 중앙구 혼마치 4-1-3", "lat": 34.6820, "lng": 135.5045, "rating": 4.0},
                    {"name": "WTC 코스모타워 전망대", "address": "오사카시 스미노에구 난코키타 1-14-16", "lat": 34.6407, "lng": 135.4129, "rating": 4.3},
                    {"name": "시텐노지 혼보 정원", "address": "오사카시 텐노지구 시텐노지 1-11-18", "lat": 34.6533, "lng": 135.5167, "rating": 4.2},
                ],
                "인스타그램": [
                    {"name": "teamLab Botanical Garden Osaka", "address": "오사카시 츠루미구 료쿠치공원 2-163", "lat": 34.7165, "lng": 135.5770, "rating": 4.6},
                    {"name": "난바 파크스 가든", "address": "오사카시 나니와구 난바나카 2-10-70", "lat": 34.6612, "lng": 135.5030, "rating": 4.4},
                    {"name": "신세카이 네온거리", "address": "오사카시 나니와구 에비스히가시 2", "lat": 34.6522, "lng": 135.5060, "rating": 4.3},
                    {"name": "아메리카무라", "address": "오사카시 중앙구 니시신사이바시 1-7", "lat": 34.6720, "lng": 135.4980, "rating": 4.2},
                    {"name": "호젠지 요코초 골목", "address": "오사카시 중앙구 난바 1-2-16", "lat": 34.6692, "lng": 135.5025, "rating": 4.4},
                ],
                "쇼핑": [
                    {"name": "신사이바시스지 상점가", "address": "오사카시 중앙구 신사이바시스지 2", "lat": 34.6720, "lng": 135.5010, "rating": 4.3},
                    {"name": "돈키호테 도톤보리점", "address": "오사카시 중앙구 소에몬쵸 7-23", "lat": 34.6693, "lng": 135.5035, "rating": 4.2},
                    {"name": "다이마루 우메다점", "address": "오사카시 키타구 우메다 3-1-1", "lat": 34.7012, "lng": 135.4962, "rating": 4.3},
                    {"name": "BIC카메라 난바점", "address": "오사카시 중앙구 센니치마에 2-10-1", "lat": 34.6643, "lng": 135.5012, "rating": 4.1},
                    {"name": "링쿠 프리미엄 아울렛", "address": "이즈미사노시 린쿠오라이미나미 3-28", "lat": 34.4262, "lng": 135.2981, "rating": 4.4},
                ],
                "시장": [
                    {"name": "구로몬 시장", "address": "오사카시 중앙구 닛폰바시 2-4-1", "lat": 34.6668, "lng": 135.5069, "rating": 4.4},
                    {"name": "텐진바시스지 상점가", "address": "오사카시 키타구 텐진바시 4-9", "lat": 34.7065, "lng": 135.5112, "rating": 4.1},
                    {"name": "센니치마에 도구야스지", "address": "오사카시 중앙구 센니치마에 2", "lat": 34.6650, "lng": 135.5050, "rating": 4.0},
                    {"name": "키레이 상점가", "address": "오사카시 텐노지구 키레 2", "lat": 34.6345, "lng": 135.5225, "rating": 4.0},
                    {"name": "츠루하시 코리아타운", "address": "오사카시 이쿠노구 모모다니 2", "lat": 34.6623, "lng": 135.5330, "rating": 4.2},
                ],
                "백화점": [
                    {"name": "한큐 우메다 본점", "address": "오사카시 키타구 카쿠다초 8-7", "lat": 34.7047, "lng": 135.4987, "rating": 4.4},
                    {"name": "다카시마야 오사카점", "address": "오사카시 중앙구 난바 5-1-5", "lat": 34.6653, "lng": 135.5013, "rating": 4.3},
                    {"name": "긴테츠 백화점 아베노 하루카스점", "address": "오사카시 아베노구 아베노스지 1-1-43", "lat": 34.6463, "lng": 135.5138, "rating": 4.5},
                    {"name": "오사카 타카시마야", "address": "오사카시 중앙구 난바 5-1-5", "lat": 34.6653, "lng": 135.5013, "rating": 4.3},
                    {"name": "한신 백화점 우메다 본점", "address": "오사카시 키타구 우메다 1-13-13", "lat": 34.7005, "lng": 135.4985, "rating": 4.2},
                ],
                "온천": [
                    {"name": "스파월드", "address": "오사카시 나니와구 에비스히가시 3-4-24", "lat": 34.6510, "lng": 135.5065, "rating": 4.3},
                    {"name": "소라니와 온천", "address": "오사카시 키타구 오요도나카 1-1-88", "lat": 34.7052, "lng": 135.4906, "rating": 4.2},
                    {"name": "난바 온천", "address": "오사카시 나니와구 난바나카 1-10-8", "lat": 34.6620, "lng": 135.5010, "rating": 4.0},
                    {"name": "텐넨온천 나니와노유", "address": "오사카시 키타구 나카쓰 1-5-18", "lat": 34.7118, "lng": 135.5002, "rating": 4.3},
                    {"name": "린쿠 온천", "address": "이즈미사노시 린쿠오라이키타 1-32", "lat": 34.4328, "lng": 135.2968, "rating": 4.1},
                ],
                "스파": [
                    {"name": "스파월드 월드", "address": "오사카시 나니와구 에비스히가시 3-4-24", "lat": 34.6510, "lng": 135.5065, "rating": 4.3},
                    {"name": "만요 클럽 오사카", "address": "오사카시 키타구 우메다 1-9-20", "lat": 34.7015, "lng": 135.4978, "rating": 4.1},
                    {"name": "오사카 게스트하우스 스파", "address": "오사카시 중앙구 도톤보리 2-3", "lat": 34.6685, "lng": 135.5020, "rating": 4.0},
                    {"name": "더 리츠칼튼 오사카 스파", "address": "오사카시 키타구 우메다 2-5-25", "lat": 34.7002, "lng": 135.4920, "rating": 4.6},
                    {"name": "세인트레지스 오사카 스파", "address": "오사카시 중앙구 혼마치 3-6-12", "lat": 34.6835, "lng": 135.5005, "rating": 4.5},
                ],
                "공원": [
                    {"name": "오사카성 공원", "address": "오사카시 중앙구 오사카조 1-1", "lat": 34.6873, "lng": 135.5262, "rating": 4.6},
                    {"name": "나카노시마 공원", "address": "오사카시 키타구 나카노시마 1", "lat": 34.6915, "lng": 135.5030, "rating": 4.4},
                    {"name": "텐노지 공원", "address": "오사카시 텐노지구 치야야마초", "lat": 34.6515, "lng": 135.5120, "rating": 4.3},
                    {"name": "쓰루미료쿠치 공원", "address": "오사카시 쓰루미구 료쿠치공원 2-163", "lat": 34.7165, "lng": 135.5770, "rating": 4.4},
                    {"name": "스미요시 공원", "address": "오사카시 스미요시구 스미요시 2-9", "lat": 34.6130, "lng": 135.4925, "rating": 4.2},
                ],
                "액티비티": [
                    {"name": "유니버설 스튜디오 재팬", "address": "오사카시 코노하나구 사쿠라지마 2-1-33", "lat": 34.6654, "lng": 135.4323, "rating": 4.5},
                    {"name": "오사카 해유관", "address": "오사카시 미나토구 가이간도리 1-1-10", "lat": 34.6545, "lng": 135.4287, "rating": 4.6},
                    {"name": "레고랜드 디스커버리 센터 오사카", "address": "오사카시 미나토구 가이간도리 1-1-10", "lat": 34.6548, "lng": 135.4292, "rating": 4.2},
                    {"name": "덴덴타운 게임센터", "address": "오사카시 나니와구 닛폰바시 4-12", "lat": 34.6598, "lng": 135.5056, "rating": 4.1},
                    {"name": "라운드원 스타디움 도톤보리점", "address": "오사카시 중앙구 소에몬쵸 7-24", "lat": 34.6695, "lng": 135.5030, "rating": 4.0},
                ],
                "체험": [
                    {"name": "컵라면 박물관 오사카이케다", "address": "이케다시 마스미쵸 8-25", "lat": 34.8249, "lng": 135.4312, "rating": 4.5},
                    {"name": "도톤보리 타코야키 체험", "address": "오사카시 중앙구 도톤보리 1-9", "lat": 34.6688, "lng": 135.5015, "rating": 4.3},
                    {"name": "기모노 체험 와사비", "address": "오사카시 중앙구 신사이바시스지 1-4", "lat": 34.6740, "lng": 135.5015, "rating": 4.4},
                    {"name": "닌자 VR 체험", "address": "오사카시 중앙구 도톤보리 1-6", "lat": 34.6685, "lng": 135.5012, "rating": 4.1},
                    {"name": "사무라이 검술 체험", "address": "오사카시 중앙구 닛폰바시 2-5", "lat": 34.6670, "lng": 135.5065, "rating": 4.3},
                ],
                "투어": [
                    {"name": "도톤보리 리버크루즈", "address": "오사카시 중앙구 도톤보리", "lat": 34.6687, "lng": 135.5010, "rating": 4.4},
                    {"name": "오사카성 요코부네", "address": "오사카시 중앙구 오사카조 3-1", "lat": 34.6850, "lng": 135.5290, "rating": 4.3},
                    {"name": "아쿠아라이너 수상버스", "address": "오사카시 중앙구 오사카조 2", "lat": 34.6870, "lng": 135.5250, "rating": 4.2},
                    {"name": "산토리 야마자키 증류소 투어", "address": "시마모토쵸 야마자키 5-2-1", "lat": 34.8950, "lng": 135.6650, "rating": 4.6},
                    {"name": "오사카 덕 투어", "address": "오사카시 키타구 나카노시마 1-1", "lat": 34.6915, "lng": 135.5030, "rating": 4.3},
                ],
            },
            "도쿄": {
                "맛집": [
                    {"name": "츠키지 스시다이", "address": "도쿄도 츄오구 츠키지 4-13-9", "lat": 35.6654, "lng": 139.7707, "rating": 4.5},
                    {"name": "이치란 라멘 시부야점", "address": "도쿄도 시부야구 진난 1-22-7", "lat": 35.6623, "lng": 139.6993, "rating": 4.4},
                    {"name": "후쿠쥬 교자", "address": "도쿄도 시부야구 에비스미나미 1-1-1", "lat": 35.6467, "lng": 139.7103, "rating": 4.3},
                    {"name": "스키야바시 지로 본점", "address": "도쿄도 츄오구 긴자 4-2-15", "lat": 35.6712, "lng": 139.7640, "rating": 4.7},
                    {"name": "아후리 라멘 에비스 본점", "address": "도쿄도 시부야구 에비스 1-1-7", "lat": 35.6473, "lng": 139.7100, "rating": 4.3},
                ],
                "관광지": [
                    {"name": "센소지", "address": "도쿄도 다이토구 아사쿠사 2-3-1", "lat": 35.7147, "lng": 139.7966, "rating": 4.5},
                    {"name": "도쿄 스카이트리", "address": "도쿄도 스미다구 오시아게 1-1-2", "lat": 35.7100, "lng": 139.8107, "rating": 4.6},
                    {"name": "메이지 신궁", "address": "도쿄도 시부야구 요요기카미조노쵸 1-1", "lat": 35.6763, "lng": 139.6993, "rating": 4.6},
                    {"name": "도쿄타워", "address": "도쿄도 미나토구 시바코엔 4-2-8", "lat": 35.6585, "lng": 139.7454, "rating": 4.4},
                    {"name": "황거 동어원", "address": "도쿄도 치요다구 치요다 1-1", "lat": 35.6852, "lng": 139.7528, "rating": 4.5},
                ],
                "포토스팟": [
                    {"name": "시부야 스크램블 교차로", "address": "도쿄도 시부야구 도겐자카 2", "lat": 35.6595, "lng": 139.7004, "rating": 4.4},
                    {"name": "도쿄역 마루노우치 역사", "address": "도쿄도 치요다구 마루노우치 1-9-1", "lat": 35.6812, "lng": 139.7671, "rating": 4.5},
                    {"name": "오다이바 레인보우 브릿지", "address": "도쿄도 미나토구 다이바", "lat": 35.6370, "lng": 139.7628, "rating": 4.4},
                    {"name": "나카메구로 벚꽃길", "address": "도쿄도 메구로구 나카메구로 1", "lat": 35.6443, "lng": 139.6993, "rating": 4.5},
                    {"name": "teamLab Borderless", "address": "도쿄도 코토구 아오미 1-3-8", "lat": 35.6267, "lng": 139.7837, "rating": 4.7},
                ],
                "쇼핑": [
                    {"name": "긴자 식스", "address": "도쿄도 츄오구 긴자 6-10-1", "lat": 35.6698, "lng": 139.7633, "rating": 4.3},
                    {"name": "하라주쿠 타케시타도리", "address": "도쿄도 시부야구 진구마에 1-17", "lat": 35.6722, "lng": 139.7054, "rating": 4.2},
                    {"name": "시부야 109", "address": "도쿄도 시부야구 도겐자카 2-29-1", "lat": 35.6592, "lng": 139.6997, "rating": 4.1},
                    {"name": "아키하바라 전자상가", "address": "도쿄도 치요다구 소토칸다 1", "lat": 35.6984, "lng": 139.7731, "rating": 4.3},
                    {"name": "아메요코 시장", "address": "도쿄도 다이토구 우에노 4", "lat": 35.7102, "lng": 139.7749, "rating": 4.2},
                ],
            },
            "교토": {
                "맛집": [
                    {"name": "기온 나루미", "address": "교토시 히가시야마구 기온마치 미나미가와 570-123", "lat": 35.0039, "lng": 135.7756, "rating": 4.4},
                    {"name": "멘바카 이치다이", "address": "교토시 카미교구 이치조도리 니시", "lat": 35.0294, "lng": 135.7540, "rating": 4.5},
                    {"name": "이노다 커피 본점", "address": "교토시 나카교구 도미노코지도리 산조사가루", "lat": 35.0088, "lng": 135.7612, "rating": 4.3},
                    {"name": "니시키 시장", "address": "교토시 나카교구 니시키코지도리", "lat": 35.0050, "lng": 135.7640, "rating": 4.4},
                    {"name": "오메닌도", "address": "교토시 히가시야마구 기요미즈 2-211", "lat": 35.0014, "lng": 135.7800, "rating": 4.2},
                ],
                "관광지": [
                    {"name": "킨카쿠지 (금각사)", "address": "교토시 키타구 킨카쿠지쵸 1", "lat": 35.0394, "lng": 135.7292, "rating": 4.6},
                    {"name": "후시미 이나리 타이샤", "address": "교토시 후시미구 후카쿠사야부노우치쵸 68", "lat": 34.9671, "lng": 135.7727, "rating": 4.7},
                    {"name": "기요미즈데라", "address": "교토시 히가시야마구 기요미즈 1-294", "lat": 34.9948, "lng": 135.7850, "rating": 4.6},
                    {"name": "아라시야마 대나무숲", "address": "교토시 우쿄구 사가텐류지 스스키노바바쵸", "lat": 35.0168, "lng": 135.6713, "rating": 4.5},
                    {"name": "니조성", "address": "교토시 나카교구 니조조마에 541", "lat": 35.0142, "lng": 135.7481, "rating": 4.5},
                ],
                "포토스팟": [
                    {"name": "야사카 탑", "address": "교토시 히가시야마구 야사카카미마치 388", "lat": 34.9987, "lng": 135.7790, "rating": 4.5},
                    {"name": "아라시야마 대나무숲", "address": "교토시 우쿄구 사가텐류지 스스키노바바쵸", "lat": 35.0168, "lng": 135.6713, "rating": 4.5},
                    {"name": "기온 거리", "address": "교토시 히가시야마구 기온마치", "lat": 35.0039, "lng": 135.7756, "rating": 4.4},
                    {"name": "철학의 길", "address": "교토시 사쿄구 긴카쿠지쵸", "lat": 35.0270, "lng": 135.7945, "rating": 4.4},
                    {"name": "토게츠쿄 다리", "address": "교토시 우쿄구 아라시야마", "lat": 35.0106, "lng": 135.6780, "rating": 4.5},
                ],
            },
            "제주도": {
                "맛집": [
                    {"name": "올래국수", "address": "제주시 귀아랑길 24", "lat": 33.5121, "lng": 126.5232, "rating": 4.4},
                    {"name": "삼대국수회관", "address": "제주시 삼성로 67", "lat": 33.4996, "lng": 126.5287, "rating": 4.3},
                    {"name": "돈사돈 본점", "address": "제주시 노형동 925-4", "lat": 33.4856, "lng": 126.4923, "rating": 4.5},
                    {"name": "제주김만복 본점", "address": "제주시 한라대학로 38", "lat": 33.5012, "lng": 126.5287, "rating": 4.4},
                    {"name": "명진전복 본점", "address": "제주시 조천읍 조함해안로 502", "lat": 33.5025, "lng": 126.5412, "rating": 4.3},
                ],
                "관광지": [
                    {"name": "성산일출봉", "address": "서귀포시 성산읍 일출로 284-12", "lat": 33.4587, "lng": 126.9425, "rating": 4.7},
                    {"name": "만장굴", "address": "제주시 구좌읍 만장굴길 182", "lat": 33.5282, "lng": 126.7712, "rating": 4.5},
                    {"name": "천지연폭포", "address": "서귀포시 천지동 667-7", "lat": 33.2469, "lng": 126.5548, "rating": 4.4},
                    {"name": "한라산 어리목 코스", "address": "제주시 해안동 산220-1", "lat": 33.3617, "lng": 126.4969, "rating": 4.6},
                    {"name": "협재해수욕장", "address": "제주시 한림읍 협재리 2497-1", "lat": 33.3939, "lng": 126.2395, "rating": 4.5},
                ],
                "포토스팟": [
                    {"name": "섭지코지", "address": "서귀포시 성산읍 섭지코지로 107", "lat": 33.4240, "lng": 126.9296, "rating": 4.5},
                    {"name": "사려니숲길", "address": "제주시 조천읍 교래리 산137-1", "lat": 33.4350, "lng": 126.6520, "rating": 4.6},
                    {"name": "카멜리아힐", "address": "서귀포시 안덕면 병악로 166", "lat": 33.2898, "lng": 126.3689, "rating": 4.4},
                    {"name": "함덕서우봉해변", "address": "제주시 조천읍 조함해안로 525", "lat": 33.5432, "lng": 126.6698, "rating": 4.5},
                    {"name": "새별오름", "address": "제주시 애월읍 봉성리", "lat": 33.3620, "lng": 126.3530, "rating": 4.5},
                ],
                "액티비티": [
                    {"name": "우도", "address": "제주시 우도면", "lat": 33.5063, "lng": 126.9520, "rating": 4.6},
                    {"name": "아쿠아플라넷 제주", "address": "서귀포시 성산읍 섭지코지로 95", "lat": 33.4337, "lng": 126.9269, "rating": 4.4},
                    {"name": "제주 레일바이크", "address": "제주시 구좌읍 용눈이오름로", "lat": 33.4610, "lng": 126.8320, "rating": 4.3},
                    {"name": "제주 동문시장 야시장", "address": "제주시 동문로 14", "lat": 33.5125, "lng": 126.5260, "rating": 4.3},
                    {"name": "카약체험 애월", "address": "제주시 애월읍 애월리", "lat": 33.4620, "lng": 126.3185, "rating": 4.4},
                ],
            },
            "부산": {
                "맛집": [
                    {"name": "할매국밥 본점", "address": "부산시 중구 구덕로 24", "lat": 35.1030, "lng": 129.0312, "rating": 4.4},
                    {"name": "원조 할매낙곱새", "address": "부산시 부산진구 서전로37번길 20", "lat": 35.1545, "lng": 129.0595, "rating": 4.5},
                    {"name": "밀면 본가", "address": "부산시 중구 대청로126번길 7", "lat": 35.1046, "lng": 129.0328, "rating": 4.3},
                    {"name": "삼진어묵 본점", "address": "부산시 영도구 태종로99번길 36", "lat": 35.0875, "lng": 129.0535, "rating": 4.4},
                    {"name": "부산 자갈치시장", "address": "부산시 중구 자갈치해안로 52", "lat": 35.0966, "lng": 129.0305, "rating": 4.3},
                ],
                "관광지": [
                    {"name": "해운대 해수욕장", "address": "부산시 해운대구 해운대해변로 264", "lat": 35.1587, "lng": 129.1604, "rating": 4.5},
                    {"name": "감천문화마을", "address": "부산시 사하구 감내2로 203", "lat": 35.0972, "lng": 129.0105, "rating": 4.4},
                    {"name": "광안리 해수욕장", "address": "부산시 수영구 광안해변로 219", "lat": 35.1532, "lng": 129.1186, "rating": 4.4},
                    {"name": "해동용궁사", "address": "부산시 기장군 기장읍 용궁길 86", "lat": 35.1881, "lng": 129.2232, "rating": 4.5},
                    {"name": "태종대", "address": "부산시 영도구 전망로 24", "lat": 35.0536, "lng": 129.0843, "rating": 4.4},
                ],
                "포토스팟": [
                    {"name": "흰여울문화마을", "address": "부산시 영도구 영선동4가", "lat": 35.0768, "lng": 129.0452, "rating": 4.4},
                    {"name": "해운대 달맞이길", "address": "부산시 해운대구 중동 산12-1", "lat": 35.1565, "lng": 129.1750, "rating": 4.3},
                    {"name": "이기대 해안산책로", "address": "부산시 남구 이기대공원로", "lat": 35.1148, "lng": 129.1185, "rating": 4.5},
                    {"name": "송정해수욕장", "address": "부산시 해운대구 송정해변로 62", "lat": 35.1785, "lng": 129.1998, "rating": 4.4},
                    {"name": "감천문화마을 어린왕자 포토존", "address": "부산시 사하구 감내2로 203", "lat": 35.0972, "lng": 129.0105, "rating": 4.4},
                ],
            },
            "방콕": {
                "맛집": [
                    {"name": "팁사마이 (Thip Samai)", "address": "313 Maha Chai Rd, Samran Rat, Bangkok", "lat": 13.7512, "lng": 100.5015, "rating": 4.4},
                    {"name": "라안 가이톤 프라투남", "address": "960 Phetchaburi Rd, Bangkok", "lat": 13.7514, "lng": 100.5395, "rating": 4.5},
                    {"name": "로디 (Roti Mataba)", "address": "136 Phra Athit Rd, Phra Borom Maha, Bangkok", "lat": 13.7608, "lng": 100.4932, "rating": 4.3},
                    {"name": "솜분 씨푸드", "address": "895/6-21 Rama I Rd, Wang Mai, Pathum Wan", "lat": 13.7460, "lng": 100.5330, "rating": 4.3},
                    {"name": "나이어트 푸드코트", "address": "555 Rajadamri Rd, Lumphini, Pathum Wan", "lat": 13.7440, "lng": 100.5395, "rating": 4.2},
                ],
                "관광지": [
                    {"name": "왓 프라깨우 (에메랄드 사원)", "address": "Na Phra Lan Rd, Phra Borom, Bangkok", "lat": 13.7516, "lng": 100.4927, "rating": 4.7},
                    {"name": "왓 아룬 (새벽 사원)", "address": "158 Wang Doem Road, Wat Arun, Bangkok", "lat": 13.7437, "lng": 100.4889, "rating": 4.6},
                    {"name": "왕궁 (Grand Palace)", "address": "Na Phra Lan Rd, Phra Borom, Bangkok", "lat": 13.7500, "lng": 100.4913, "rating": 4.6},
                    {"name": "짜뚜짝 주말시장", "address": "Kamphaeng Phet 2 Rd, Chatuchak, Bangkok", "lat": 13.7999, "lng": 100.5506, "rating": 4.4},
                    {"name": "왓 포", "address": "2 Sanam Chai Rd, Phra Borom Maha, Bangkok", "lat": 13.7465, "lng": 100.4927, "rating": 4.6},
                ],
                "포토스팟": [
                    {"name": "아이콘시암", "address": "299 Charoen Nakhon Rd, Khlong Ton Sai, Khlong San", "lat": 13.7263, "lng": 100.5100, "rating": 4.5},
                    {"name": "카오산 로드", "address": "Khaosan Rd, Talat Yot, Phra Nakhon, Bangkok", "lat": 13.7589, "lng": 100.4970, "rating": 4.2},
                    {"name": "마하나콘 스카이워크", "address": "114 Narathiwat Rd, Silom, Bang Rak", "lat": 13.7235, "lng": 100.5269, "rating": 4.5},
                    {"name": "왓 팍남 대형 불상", "address": "Wat Paknam Phasi Charoen, Bangkok", "lat": 13.7215, "lng": 100.4765, "rating": 4.5},
                    {"name": "아시아티크 더 리버프론트", "address": "2194 Charoen Krung Rd, Wat Phraya Krai, Bangkok", "lat": 13.7038, "lng": 100.5014, "rating": 4.3},
                ],
            },
            "파리": {
                "맛집": [
                    {"name": "르 꽁투아 뒤 팡테옹", "address": "5 Rue Soufflot, 75005 Paris", "lat": 48.8462, "lng": 2.3439, "rating": 4.4},
                    {"name": "르 프로콥", "address": "13 Rue de l'Ancienne Comédie, 75006 Paris", "lat": 48.8531, "lng": 2.3390, "rating": 4.3},
                    {"name": "세셰롱", "address": "7 Rue de la Grande Chaumière, 75006 Paris", "lat": 48.8442, "lng": 2.3315, "rating": 4.5},
                    {"name": "카페 드 플로르", "address": "172 Boulevard Saint-Germain, 75006 Paris", "lat": 48.8540, "lng": 2.3325, "rating": 4.2},
                    {"name": "라뒤레 샹젤리제점", "address": "75 Avenue des Champs-Élysées, 75008 Paris", "lat": 48.8711, "lng": 2.3042, "rating": 4.4},
                ],
                "관광지": [
                    {"name": "에펠탑", "address": "Champ de Mars, 5 Avenue Anatole France, 75007 Paris", "lat": 48.8584, "lng": 2.2945, "rating": 4.7},
                    {"name": "루브르 박물관", "address": "Rue de Rivoli, 75001 Paris", "lat": 48.8606, "lng": 2.3376, "rating": 4.8},
                    {"name": "개선문", "address": "Place Charles de Gaulle, 75008 Paris", "lat": 48.8738, "lng": 2.2950, "rating": 4.6},
                    {"name": "노트르담 대성당", "address": "6 Parvis Notre-Dame, 75004 Paris", "lat": 48.8530, "lng": 2.3499, "rating": 4.7},
                    {"name": "몽마르트르 사크레쾨르 대성당", "address": "35 Rue du Chevalier de la Barre, 75018 Paris", "lat": 48.8867, "lng": 2.3431, "rating": 4.6},
                ],
                "포토스팟": [
                    {"name": "트로카데로 광장", "address": "Place du Trocadéro, 75016 Paris", "lat": 48.8624, "lng": 2.2879, "rating": 4.5},
                    {"name": "퐁 데자르 (예술의 다리)", "address": "Pont des Arts, 75006 Paris", "lat": 48.8583, "lng": 2.3375, "rating": 4.4},
                    {"name": "몽마르트르 언덕", "address": "Montmartre, 75018 Paris", "lat": 48.8867, "lng": 2.3431, "rating": 4.5},
                    {"name": "튈르리 정원", "address": "Place de la Concorde, 75001 Paris", "lat": 48.8634, "lng": 2.3275, "rating": 4.4},
                    {"name": "뤽상부르 공원", "address": "75006 Paris", "lat": 48.8462, "lng": 2.3371, "rating": 4.6},
                ],
            },
        }

        # 쿼리 키워드 정규화 - 다양한 검색어를 카테고리에 매핑
        query_lower = query.lower()
        query_normalized = query

        # 검색어 매핑
        query_mappings = {
            "맛집": ["맛집", "레스토랑", "현지 음식", "음식점", "식당"],
            "관광지": ["관광지", "명소", "랜드마크", "볼거리"],
            "포토스팟": ["포토스팟", "뷰포인트", "인스타그램", "사진", "촬영"],
            "쇼핑": ["쇼핑", "시장", "백화점", "아울렛"],
            "온천": ["온천", "스파", "휴식"],
            "공원": ["공원", "정원"],
            "액티비티": ["액티비티", "체험", "투어", "놀거리"],
        }

        for category, keywords in query_mappings.items():
            if any(kw in query_lower for kw in keywords):
                query_normalized = category
                break

        # 해당 지역의 장소 데이터 가져오기
        location_data = None
        for loc_key in real_places_db:
            if loc_key in location:
                location_data = real_places_db[loc_key]
                break

        if not location_data:
            # 기본 지역으로 오사카 사용
            location_data = real_places_db.get("오사카", {})

        # 해당 카테고리의 장소 찾기
        places = location_data.get(query_normalized, [])

        # 해당 카테고리가 없으면 유사 카테고리 시도
        if not places:
            for cat in location_data:
                if query_normalized.lower() in cat.lower() or cat.lower() in query_normalized.lower():
                    places = location_data[cat]
                    break

        # 여전히 없으면 맛집 또는 관광지 기본값 사용
        if not places:
            places = location_data.get("맛집", location_data.get("관광지", []))

        # 결과 포맷팅
        mock_places = []
        for i, place in enumerate(places[:max_results]):
            mock_places.append({
                "place_id": f"real_place_{i}_{place['name'][:10]}",
                "name": place["name"],
                "address": place["address"],
                "location": {
                    "lat": place["lat"],
                    "lng": place["lng"],
                },
                "rating": place.get("rating", 4.3),
                "user_ratings_total": 300 + (i * 50),
                "types": ["establishment"],
                "price_level": min(i + 1, 4),
                "open_now": True,
            })

        return mock_places

    def _get_mock_place_details(
        self,
        place_name: str,
        location: str,
    ) -> Dict[str, Any]:
        """Mock 장소 상세 데이터 생성."""
        location_coords = {
            "오사카": (34.6937, 135.5023),
            "도쿄": (35.6762, 139.6503),
        }

        base_lat, base_lng = location_coords.get(location, (35.6762, 139.6503))

        return {
            "place_id": f"mock_{place_name}",
            "name": place_name,
            "address": f"{location} 중심가",
            "location": {"lat": base_lat, "lng": base_lng},
            "rating": 4.3,
            "user_ratings_total": 350,
            "price_level": 2,
            "opening_hours": ["월-금: 10:00-22:00", "토-일: 11:00-21:00"],
            "website": None,
            "phone": None,
            "types": ["establishment"],
            "reviews": [
                {"rating": 5, "text": "정말 좋았어요!", "time": "일주일 전"},
                {"rating": 4, "text": "분위기가 좋습니다", "time": "한달 전"},
            ],
        }


# Singleton instance
places_tool = PlacesTool()
