"""Exchange rate API tool."""

from typing import Dict, Optional
import httpx
from tenacity import retry, stop_after_attempt, wait_exponential

from core.config import settings
from core.logger import logger


class ExchangeTool:
    """환율 조회 도구."""

    def __init__(self):
        """Initialize exchange tool."""
        self.base_url = settings.exchange_rate_base_url

    # 실시간 환율 데이터 캐시 (실제로는 Redis 등 사용)
    _cache: Dict[str, Dict] = {}

    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=1, max=5),
    )
    async def get_exchange_rate(
        self,
        from_currency: str = "KRW",
        to_currency: str = "JPY",
    ) -> Dict[str, any]:
        """
        환율을 조회합니다.

        Args:
            from_currency: 기준 통화 (예: KRW)
            to_currency: 대상 통화 (예: JPY)

        Returns:
            환율 정보
        """
        from_currency = from_currency.upper()
        to_currency = to_currency.upper()

        cache_key = f"{from_currency}_{to_currency}"

        # 캐시 확인
        if cache_key in self._cache:
            logger.debug(f"Exchange rate cache hit: {cache_key}")
            return self._cache[cache_key]

        try:
            async with httpx.AsyncClient() as client:
                # 무료 환율 API 사용
                response = await client.get(
                    f"{self.base_url}/latest/{from_currency}",
                    timeout=10.0,
                )

                if response.status_code != 200:
                    logger.warning(f"Exchange API error: {response.status_code}")
                    return self._get_fallback_rate(from_currency, to_currency)

                data = response.json()
                rates = data.get("rates", {})

                if to_currency not in rates:
                    logger.warning(f"Currency not found: {to_currency}")
                    return self._get_fallback_rate(from_currency, to_currency)

                rate = rates[to_currency]
                result = {
                    "from_currency": from_currency,
                    "to_currency": to_currency,
                    "rate": rate,
                    "inverse_rate": 1 / rate if rate > 0 else 0,
                    "example": {
                        "amount": 10000,
                        "converted": round(10000 * rate, 2),
                        "description": f"10,000 {from_currency} = {round(10000 * rate, 2)} {to_currency}",
                    },
                }

                # 캐시 저장
                self._cache[cache_key] = result
                logger.info(f"Exchange rate: {from_currency} -> {to_currency} = {rate}")

                return result

        except Exception as e:
            logger.error(f"Exchange rate error: {e}")
            return self._get_fallback_rate(from_currency, to_currency)

    def _get_fallback_rate(
        self,
        from_currency: str,
        to_currency: str,
    ) -> Dict[str, any]:
        """
        API 실패 시 대체 환율 데이터 반환.
        실제 환율과 다를 수 있음을 명시.
        """
        # 2024년 기준 대략적인 환율 (참고용)
        fallback_rates = {
            ("KRW", "JPY"): 0.11,      # 1 KRW = 0.11 JPY
            ("KRW", "USD"): 0.00075,   # 1 KRW = 0.00075 USD
            ("KRW", "EUR"): 0.00069,   # 1 KRW = 0.00069 EUR
            ("KRW", "THB"): 0.027,     # 1 KRW = 0.027 THB
            ("KRW", "CNY"): 0.0054,    # 1 KRW = 0.0054 CNY
            ("JPY", "KRW"): 9.1,       # 1 JPY = 9.1 KRW
            ("USD", "KRW"): 1330,      # 1 USD = 1330 KRW
        }

        rate = fallback_rates.get(
            (from_currency, to_currency),
            1.0  # 알 수 없는 통화 쌍은 1:1
        )

        return {
            "from_currency": from_currency,
            "to_currency": to_currency,
            "rate": rate,
            "inverse_rate": 1 / rate if rate > 0 else 0,
            "is_fallback": True,  # 대체 데이터임을 표시
            "example": {
                "amount": 10000,
                "converted": round(10000 * rate, 2),
                "description": f"10,000 {from_currency} ≈ {round(10000 * rate, 2)} {to_currency} (참고값)",
            },
        }

    def convert_amount(
        self,
        amount: float,
        rate_info: Dict,
    ) -> float:
        """
        금액을 환산합니다.

        Args:
            amount: 원본 금액
            rate_info: get_exchange_rate 결과

        Returns:
            환산된 금액
        """
        return round(amount * rate_info["rate"], 2)


# Singleton instance
exchange_tool = ExchangeTool()
