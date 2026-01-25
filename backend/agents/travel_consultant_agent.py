"""Travel Consultant Agent - AI 기반 여행 상담."""

from typing import Any, AsyncGenerator, Dict, List, Optional

from core.logger import logger
from core.exceptions import AIServiceException
from services.openai_service import openai_service
from tools import places_tool, exchange_tool, translate_tool
from tools.definitions import CONSULTANT_TOOLS


class TravelConsultantAgent:
    """
    AI 여행 컨설턴트 Agent.

    OpenAI GPT를 사용하여 실시간 여행 관련 질의응답 및
    맞춤 추천을 제공합니다.
    """

    def __init__(self):
        """Initialize Travel Consultant Agent."""
        self.system_prompt = self._build_system_prompt()

    def _build_system_prompt(self) -> str:
        """시스템 프롬프트 생성."""
        return """당신은 친절하고 전문적인 AI 여행 컨설턴트입니다.
사용자의 여행 관련 질문에 도움을 제공합니다.

## 역할
- 여행지 맛집, 숙소, 관광지 추천
- 현지 정보 제공 (교통, 문화, 팁)
- 환율 정보 안내
- 간단한 현지어 번역
- 여행 일정 조언

## 응답 가이드라인
1. 친근하면서도 전문적인 톤 유지
2. 구체적이고 실용적인 정보 제공
3. 필요시 도구를 활용하여 최신 정보 확인
4. 추천 시 이유와 함께 설명
5. 한국어로 응답 (외국어는 발음과 함께)

## 도구 사용
- search_places: 장소 검색이 필요할 때
- get_exchange_rate: 환율 문의 시
- translate_text: 번역 요청 시
- get_current_trip: 현재 일정 확인 필요 시

사용자에게 도움이 되는 정보를 제공하세요."""

    async def chat(
        self,
        message: str,
        history: List[Dict[str, str]],
        trip_context: Optional[Dict[str, Any]] = None,
    ) -> Dict[str, Any]:
        """
        사용자 메시지에 응답합니다.

        Args:
            message: 사용자 메시지
            history: 대화 히스토리
            trip_context: 현재 여행 컨텍스트 (있는 경우)

        Returns:
            응답 결과 (response, tools_used)
        """
        logger.info(f"Consultant chat: {message[:50]}...")

        # 컨텍스트 추가
        context_info = ""
        if trip_context:
            context_info = f"""

## 현재 여행 정보
- 목적지: {trip_context.get('destination', '미정')}
- 기간: {trip_context.get('period', '미정')}
- 현재 위치: {trip_context.get('current_location', '미정')}"""

        system_message = self.system_prompt + context_info

        # 메시지 구성
        messages = [{"role": "system", "content": system_message}]

        # 히스토리 추가 (최근 10개만)
        for h in history[-10:]:
            messages.append({
                "role": h.get("role", "user"),
                "content": h.get("content", ""),
            })

        # 현재 메시지 추가
        messages.append({"role": "user", "content": message})

        # Tool handlers 정의
        tool_handlers = {
            "search_places": self._handle_search_places,
            "get_exchange_rate": self._handle_exchange_rate,
            "translate_text": self._handle_translate,
            "get_current_trip": self._handle_get_trip,
        }

        if openai_service.is_available():
            try:
                response = await openai_service.execute_with_tools(
                    messages=messages,
                    tools=CONSULTANT_TOOLS,
                    tool_handlers=tool_handlers,
                    max_iterations=3,
                )

                return {
                    "response": response["content"],
                    "tools_used": response.get("tools_used", []),
                }

            except Exception as e:
                logger.error(f"OpenAI consultant error: {e}")

        # Fallback 응답
        return {
            "response": self._generate_fallback_response(message),
            "tools_used": [],
        }

    async def chat_stream(
        self,
        message: str,
        history: List[Dict[str, str]],
        trip_context: Optional[Dict[str, Any]] = None,
    ) -> AsyncGenerator[str, None]:
        """
        스트리밍 방식으로 응답합니다.

        Args:
            message: 사용자 메시지
            history: 대화 히스토리
            trip_context: 현재 여행 컨텍스트

        Yields:
            응답 텍스트 청크
        """
        logger.info(f"Consultant stream: {message[:50]}...")

        context_info = ""
        if trip_context:
            context_info = f"\n현재 여행: {trip_context.get('destination', '')}"

        system_message = self.system_prompt + context_info

        messages = [{"role": "system", "content": system_message}]

        for h in history[-10:]:
            messages.append({
                "role": h.get("role", "user"),
                "content": h.get("content", ""),
            })

        messages.append({"role": "user", "content": message})

        if openai_service.is_available():
            try:
                async for chunk in openai_service.chat_completion_stream(
                    messages=messages,
                    temperature=0.7,
                ):
                    yield chunk
                return
            except Exception as e:
                logger.error(f"Streaming error: {e}")

        # Fallback
        fallback = self._generate_fallback_response(message)
        for char in fallback:
            yield char

    async def _handle_search_places(
        self,
        query: str,
        location: str,
        radius_km: float = 1.0,
        **kwargs,
    ) -> Dict[str, Any]:
        """장소 검색 도구 핸들러."""
        try:
            results = await places_tool.search_places(
                query=query,
                location=location,
                radius_km=radius_km,
                max_results=5,
            )
            return {
                "places": results,
                "count": len(results),
                "query": query,
                "location": location,
            }
        except Exception as e:
            logger.error(f"Search places error: {e}")
            return {"error": str(e), "places": []}

    async def _handle_exchange_rate(
        self,
        from_currency: str = "KRW",
        to_currency: str = "JPY",
        **kwargs,
    ) -> Dict[str, Any]:
        """환율 조회 도구 핸들러."""
        try:
            result = await exchange_tool.get_exchange_rate(
                from_currency=from_currency,
                to_currency=to_currency,
            )
            return result
        except Exception as e:
            logger.error(f"Exchange rate error: {e}")
            return {"error": str(e)}

    async def _handle_translate(
        self,
        text: str,
        target_language: str,
        source_language: str = "ko",
        **kwargs,
    ) -> Dict[str, Any]:
        """번역 도구 핸들러."""
        try:
            result = await translate_tool.translate_text(
                text=text,
                target_language=target_language,
                source_language=source_language,
            )

            # AI 번역이 필요한 경우
            if result.get("needs_ai_translation") and openai_service.is_available():
                lang_name = result["target_language_name"]
                translation_prompt = f"다음 텍스트를 {lang_name}로 번역해주세요. 발음도 함께 알려주세요:\n\n{text}"

                response = await openai_service.chat_completion(
                    messages=[{"role": "user", "content": translation_prompt}],
                    temperature=0.3,
                    max_completion_tokens=500,
                )

                result["translated"] = response["content"]
                result["needs_ai_translation"] = False

            return result
        except Exception as e:
            logger.error(f"Translation error: {e}")
            return {"error": str(e), "original": text}

    async def _handle_get_trip(
        self,
        trip_id: str,
        **kwargs,
    ) -> Dict[str, Any]:
        """현재 여행 조회 도구 핸들러."""
        # 실제로는 DB에서 조회
        # 여기서는 placeholder
        return {
            "trip_id": trip_id,
            "message": "여행 정보를 조회했습니다.",
        }

    def _generate_fallback_response(self, message: str) -> str:
        """Fallback 응답 생성."""
        message_lower = message.lower()

        if any(word in message_lower for word in ["맛집", "음식", "먹", "레스토랑"]):
            return """맛집 추천을 원하시는군요!

현재 AI 서비스 연결이 원활하지 않아 실시간 검색이 어렵습니다.

대신 일반적인 팁을 드리면:
1. Google Maps에서 평점 4.0 이상인 곳을 찾아보세요
2. 현지인이 많이 가는 곳이 보통 맛있어요
3. 점심 시간은 피크타임이라 대기가 길 수 있어요

조금 후에 다시 시도해주시면 더 자세한 추천을 드릴 수 있을 거예요!"""

        if any(word in message_lower for word in ["환율", "돈", "원화", "엔화"]):
            return """환율 정보를 원하시는군요!

현재 서비스 연결이 원활하지 않아 실시간 환율 조회가 어렵습니다.

일반적인 팁:
- 공항보다 시내 환전소가 유리한 경우가 많아요
- 신용카드 해외 결제도 괜찮은 편이에요
- 대형 쇼핑몰에서는 보통 카드 결제가 가능해요

실시간 환율은 네이버나 구글에서 확인해보세요!"""

        if any(word in message_lower for word in ["번역", "말", "어떻게"]):
            return """번역/현지어 도움을 원하시는군요!

자주 쓰이는 표현들:

🇯🇵 일본어
- 안녕하세요: こんにちは (곤니치와)
- 감사합니다: ありがとう (아리가또)
- 이거 주세요: これください (코레 쿠다사이)
- 얼마예요?: いくらですか (이쿠라데스카)

궁금한 표현이 있으시면 말씀해주세요!"""

        return """안녕하세요! AI 여행 컨설턴트입니다.

현재 서비스 연결이 원활하지 않아 일부 기능이 제한될 수 있습니다.

도움 드릴 수 있는 것들:
- 여행지 맛집/관광지 추천
- 환율 정보
- 간단한 현지어 번역
- 여행 팁

무엇이 궁금하신가요?"""


# Singleton instance
travel_consultant_agent = TravelConsultantAgent()
