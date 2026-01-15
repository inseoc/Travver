"""Tool definitions for OpenAI function calling."""

# Travel Planner Agent용 도구 정의
TRAVEL_PLANNER_TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "search_places",
            "description": "목적지에서 관광지, 맛집, 숙소 등을 검색합니다. "
                          "여행 스타일과 키워드에 맞는 장소를 찾을 때 사용합니다.",
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "검색할 장소 키워드 (예: '라멘 맛집', '관광 명소')",
                    },
                    "location": {
                        "type": "string",
                        "description": "검색할 지역 (예: '오사카', '도쿄 시부야')",
                    },
                    "place_type": {
                        "type": "string",
                        "enum": ["restaurant", "tourist_attraction", "lodging", "shopping_mall", "cafe"],
                        "description": "장소 유형",
                    },
                    "max_results": {
                        "type": "integer",
                        "description": "최대 검색 결과 수 (기본: 5)",
                        "default": 5,
                    },
                },
                "required": ["query", "location"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_place_details",
            "description": "특정 장소의 상세 정보(영업시간, 리뷰, 가격대, 좌표 등)를 조회합니다.",
            "parameters": {
                "type": "object",
                "properties": {
                    "place_id": {
                        "type": "string",
                        "description": "Google Places ID",
                    },
                    "place_name": {
                        "type": "string",
                        "description": "장소명 (place_id가 없을 경우 사용)",
                    },
                    "location": {
                        "type": "string",
                        "description": "장소가 위치한 지역",
                    },
                },
                "required": ["place_name", "location"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_exchange_rate",
            "description": "현지 통화의 환율을 조회합니다. 예산 계산에 사용합니다.",
            "parameters": {
                "type": "object",
                "properties": {
                    "from_currency": {
                        "type": "string",
                        "description": "기준 통화 코드 (예: 'KRW')",
                        "default": "KRW",
                    },
                    "to_currency": {
                        "type": "string",
                        "description": "대상 통화 코드 (예: 'JPY', 'USD')",
                    },
                },
                "required": ["to_currency"],
            },
        },
    },
]

# Travel Consultant Agent용 도구 정의
CONSULTANT_TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "search_places",
            "description": "주변 장소를 검색합니다. 맛집, 관광지 추천 등에 사용합니다.",
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {
                        "type": "string",
                        "description": "검색 키워드",
                    },
                    "location": {
                        "type": "string",
                        "description": "검색할 지역",
                    },
                    "radius_km": {
                        "type": "number",
                        "description": "검색 반경 (km)",
                        "default": 1.0,
                    },
                },
                "required": ["query", "location"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_exchange_rate",
            "description": "환율 정보를 조회합니다.",
            "parameters": {
                "type": "object",
                "properties": {
                    "from_currency": {
                        "type": "string",
                        "default": "KRW",
                    },
                    "to_currency": {
                        "type": "string",
                    },
                },
                "required": ["to_currency"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "translate_text",
            "description": "텍스트를 현지어로 번역합니다.",
            "parameters": {
                "type": "object",
                "properties": {
                    "text": {
                        "type": "string",
                        "description": "번역할 텍스트",
                    },
                    "source_language": {
                        "type": "string",
                        "description": "원본 언어 (예: 'ko', 'en')",
                        "default": "ko",
                    },
                    "target_language": {
                        "type": "string",
                        "description": "대상 언어 (예: 'ja', 'en')",
                    },
                },
                "required": ["text", "target_language"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_current_trip",
            "description": "현재 진행 중인 여행 일정을 조회합니다.",
            "parameters": {
                "type": "object",
                "properties": {
                    "trip_id": {
                        "type": "string",
                        "description": "여행 ID",
                    },
                },
                "required": ["trip_id"],
            },
        },
    },
]
