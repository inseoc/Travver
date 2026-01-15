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
            # 먼저 지역의 좌표를 가져옴
            geocode_url = f"https://maps.googleapis.com/maps/api/geocode/json"
            async with httpx.AsyncClient() as client:
                geo_response = await client.get(
                    geocode_url,
                    params={"address": location, "key": self.api_key},
                )
                geo_data = geo_response.json()

                if geo_data.get("status") != "OK" or not geo_data.get("results"):
                    logger.warning(f"Geocoding failed for: {location}")
                    return self._get_mock_places(query, location, max_results)

                lat = geo_data["results"][0]["geometry"]["location"]["lat"]
                lng = geo_data["results"][0]["geometry"]["location"]["lng"]

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
            async with httpx.AsyncClient() as client:
                # place_id가 없으면 검색해서 가져옴
                if not place_id:
                    places = await self.search_places(place_name, location, max_results=1)
                    if places:
                        place_id = places[0].get("place_id")

                if not place_id:
                    return self._get_mock_place_details(place_name, location)

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
        """Mock 장소 데이터 생성."""
        # 지역별 기본 좌표
        location_coords = {
            "오사카": (34.6937, 135.5023),
            "도쿄": (35.6762, 139.6503),
            "교토": (35.0116, 135.7681),
            "방콕": (13.7563, 100.5018),
            "파리": (48.8566, 2.3522),
            "제주도": (33.4996, 126.5312),
            "부산": (35.1796, 129.0756),
        }

        base_lat, base_lng = location_coords.get(location, (35.6762, 139.6503))

        mock_places = []
        for i in range(min(max_results, 5)):
            mock_places.append({
                "place_id": f"mock_place_{i}",
                "name": f"{location} {query} {i + 1}번 추천",
                "address": f"{location} 중심가 {i + 1}번지",
                "location": {
                    "lat": base_lat + (i * 0.002),
                    "lng": base_lng + (i * 0.002),
                },
                "rating": 4.5 - (i * 0.1),
                "user_ratings_total": 500 - (i * 50),
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
