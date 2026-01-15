"""Translation tool using OpenAI."""

from typing import Dict, Optional
from core.logger import logger


class TranslateTool:
    """번역 도구 (OpenAI 기반)."""

    # 언어 코드 매핑
    LANGUAGE_NAMES = {
        "ko": "한국어",
        "en": "영어",
        "ja": "일본어",
        "zh": "중국어",
        "th": "태국어",
        "vi": "베트남어",
        "fr": "프랑스어",
        "de": "독일어",
        "es": "스페인어",
        "it": "이탈리아어",
    }

    # 자주 쓰는 여행 표현 사전 (오프라인 대비)
    COMMON_PHRASES = {
        "ja": {
            "안녕하세요": "こんにちは (Konnichiwa)",
            "감사합니다": "ありがとうございます (Arigatou gozaimasu)",
            "죄송합니다": "すみません (Sumimasen)",
            "이거 얼마예요?": "これはいくらですか？ (Kore wa ikura desu ka?)",
            "화장실이 어디예요?": "トイレはどこですか？ (Toire wa doko desu ka?)",
            "계산해주세요": "お会計お願いします (Okaikei onegaishimasu)",
            "영어 할 수 있어요?": "英語できますか？ (Eigo dekimasu ka?)",
            "메뉴판 주세요": "メニューをください (Menu wo kudasai)",
            "추천해주세요": "おすすめは何ですか？ (Osusume wa nan desu ka?)",
            "맛있어요": "おいしいです (Oishii desu)",
        },
        "en": {
            "안녕하세요": "Hello",
            "감사합니다": "Thank you",
            "죄송합니다": "I'm sorry / Excuse me",
            "이거 얼마예요?": "How much is this?",
            "화장실이 어디예요?": "Where is the restroom?",
            "계산해주세요": "Check, please",
            "메뉴판 주세요": "Can I see the menu?",
            "추천해주세요": "What do you recommend?",
        },
        "zh": {
            "안녕하세요": "你好 (Nǐ hǎo)",
            "감사합니다": "谢谢 (Xièxiè)",
            "이거 얼마예요?": "这个多少钱？ (Zhège duōshǎo qián?)",
            "화장실이 어디예요?": "洗手间在哪里？ (Xǐshǒujiān zài nǎlǐ?)",
        },
        "th": {
            "안녕하세요": "สวัสดี (Sawatdee)",
            "감사합니다": "ขอบคุณ (Khop khun)",
            "이거 얼마예요?": "อันนี้เท่าไหร่ (An nee tao rai?)",
        },
    }

    async def translate_text(
        self,
        text: str,
        target_language: str,
        source_language: str = "ko",
    ) -> Dict[str, str]:
        """
        텍스트를 번역합니다.

        Args:
            text: 번역할 텍스트
            target_language: 대상 언어 코드
            source_language: 원본 언어 코드

        Returns:
            번역 결과
        """
        target_language = target_language.lower()
        source_language = source_language.lower()

        # 자주 쓰는 표현인지 확인
        if target_language in self.COMMON_PHRASES:
            phrases = self.COMMON_PHRASES[target_language]
            normalized_text = text.strip()

            if normalized_text in phrases:
                logger.debug(f"Found cached translation for: {text}")
                return {
                    "original": text,
                    "translated": phrases[normalized_text],
                    "source_language": source_language,
                    "target_language": target_language,
                    "source_language_name": self.LANGUAGE_NAMES.get(source_language, source_language),
                    "target_language_name": self.LANGUAGE_NAMES.get(target_language, target_language),
                }

        # OpenAI를 사용한 번역 (서비스 레이어에서 호출)
        # 여기서는 번역 요청 형식만 반환
        logger.info(f"Translation request: {source_language} -> {target_language}")

        return {
            "original": text,
            "translated": None,  # AI 서비스에서 채워짐
            "source_language": source_language,
            "target_language": target_language,
            "source_language_name": self.LANGUAGE_NAMES.get(source_language, source_language),
            "target_language_name": self.LANGUAGE_NAMES.get(target_language, target_language),
            "needs_ai_translation": True,
        }

    def get_common_phrases(
        self,
        target_language: str,
    ) -> Dict[str, str]:
        """
        특정 언어의 자주 쓰는 여행 표현을 반환합니다.

        Args:
            target_language: 대상 언어 코드

        Returns:
            자주 쓰는 표현 사전
        """
        return self.COMMON_PHRASES.get(target_language.lower(), {})

    def get_supported_languages(self) -> Dict[str, str]:
        """지원하는 언어 목록 반환."""
        return self.LANGUAGE_NAMES.copy()


# Singleton instance
translate_tool = TranslateTool()
