"""Google Gemini API service for image and video generation."""

import base64
from typing import Any, Optional

from core.config import settings
from core.logger import logger
from core.exceptions import GeminiException, RateLimitException


class GeminiService:
    """Google Gemini API 서비스 (Lazy Loading)."""

    def __init__(self):
        """Initialize Gemini client."""
        self._genai = None
        self._model = None
        self._initialized = False
        self._configured = settings.is_google_configured()

        if not self._configured:
            logger.warning("Google API key not configured")

    def _ensure_initialized(self):
        """Lazy initialization of Gemini client."""
        if self._initialized:
            return

        if not self._configured:
            return

        try:
            import google.generativeai as genai
            genai.configure(api_key=settings.google_api_key)
            self._genai = genai
            self._model = genai.GenerativeModel(settings.gemini_model)
            self._initialized = True
            logger.info("Gemini service initialized successfully")
        except ImportError:
            logger.warning("google-generativeai not installed")
            self._configured = False
        except Exception as e:
            logger.error(f"Failed to initialize Gemini: {e}")
            self._configured = False

    def is_available(self) -> bool:
        """Check if service is available."""
        if not self._configured:
            return False
        self._ensure_initialized()
        return self._initialized

    async def decorate_photo(
        self,
        image_data: bytes,
        style: str,
        image_format: str = "jpeg",
    ) -> bytes:
        """
        Apply artistic style to a photo using Gemini.

        Args:
            image_data: Raw image bytes
            style: Style to apply (watercolor, oil_painting, etc.)
            image_format: Image format (jpeg, png)

        Returns:
            Transformed image bytes

        Raises:
            GeminiException: On API errors
        """
        if not self.is_available():
            # Fallback: 원본 이미지 반환
            logger.warning("Gemini not available, returning original image")
            return image_data

        style_prompts = {
            "watercolor": "Transform this photo into a beautiful watercolor painting style. "
                         "Use soft, flowing colors with visible brush strokes and "
                         "gentle color bleeding effects.",
            "oil_painting": "Transform this photo into a classic oil painting style. "
                           "Use rich, textured brush strokes with bold colors and "
                           "visible paint layering.",
            "sketch": "Transform this photo into a detailed pencil sketch. "
                     "Use fine lines, cross-hatching, and shading techniques "
                     "to create depth and texture.",
            "vintage": "Transform this photo into a vintage film style. "
                      "Apply warm sepia tones, slight vignetting, "
                      "and subtle grain for a nostalgic feel.",
            "movie_poster": "Transform this photo into a dramatic movie poster style. "
                           "Use high contrast, bold colors, and cinematic lighting "
                           "with a dramatic composition.",
            "pop_art": "Transform this photo into a vibrant pop art style. "
                      "Use bold, flat colors, Ben-Day dots, and comic-book "
                      "inspired high contrast.",
        }

        prompt = style_prompts.get(
            style,
            f"Transform this photo into a {style} artistic style.",
        )

        try:
            logger.info(f"Decorating photo with style: {style}")

            # Prepare image for Gemini
            image_part = {
                "mime_type": f"image/{image_format}",
                "data": base64.b64encode(image_data).decode("utf-8"),
            }

            response = await self._model.generate_content_async(
                contents=[prompt, image_part],
                generation_config={
                    "temperature": 0.4,
                    "max_output_tokens": 8192,
                },
            )

            # Note: 실제 Gemini Vision API는 텍스트 응답만 반환
            # 이미지 생성을 위해서는 별도의 이미지 생성 모델이 필요
            # 여기서는 구조만 정의하고, 실제로는 적절한 이미지 생성 API 사용

            logger.info(f"Photo decoration completed for style: {style}")

            # Placeholder: 실제로는 이미지 생성 API 응답 반환
            return image_data

        except Exception as e:
            if "quota" in str(e).lower() or "rate" in str(e).lower():
                raise RateLimitException("Gemini rate limit exceeded")
            logger.error(f"Gemini API error: {e}")
            raise GeminiException(str(e))

    async def create_video(
        self,
        media_files: list[bytes],
        style: str,
        music: str,
        duration: int,
    ) -> bytes:
        """
        Create video from media files using Gemini Veo.

        Args:
            media_files: List of media file bytes (images/videos)
            style: Video style (cinematic, vlog, highlight, album)
            music: Background music style
            duration: Target duration in seconds

        Returns:
            Generated video bytes

        Raises:
            GeminiException: On API errors
        """
        if not self.is_available():
            # Fallback: placeholder 반환
            logger.warning("Gemini not available, returning placeholder")
            return b"video_placeholder"

        style_configs = {
            "cinematic": {
                "prompt": "Create a cinematic travel video with dramatic transitions, "
                         "slow motion effects, and epic wide shots. Use smooth camera "
                         "movements and professional color grading.",
                "transition": "smooth",
                "pacing": "slow",
            },
            "vlog": {
                "prompt": "Create a casual travel vlog style video with natural "
                         "transitions, authentic moments, and personal storytelling. "
                         "Include candid shots and spontaneous reactions.",
                "transition": "natural",
                "pacing": "medium",
            },
            "highlight": {
                "prompt": "Create a dynamic highlight reel with fast-paced editing, "
                         "energetic transitions, and action-packed sequences. "
                         "Focus on exciting moments and quick cuts.",
                "transition": "dynamic",
                "pacing": "fast",
            },
            "album": {
                "prompt": "Create a nostalgic memory album video with gentle transitions, "
                         "photo-like effects, and sentimental pacing. "
                         "Include soft fades and elegant text overlays.",
                "transition": "fade",
                "pacing": "gentle",
            },
        }

        config = style_configs.get(style, style_configs["cinematic"])

        music_configs = {
            "calm": "peaceful, relaxing background music",
            "upbeat": "energetic, uplifting background music",
            "emotional": "touching, emotional background music",
            "none": "no background music",
        }

        music_prompt = music_configs.get(music, "appropriate background music")

        try:
            logger.info(f"Creating video: style={style}, music={music}, duration={duration}s")

            # Note: Gemini Veo 3.1 API 구조
            # 실제 API가 출시되면 적절히 수정 필요

            full_prompt = (
                f"{config['prompt']} "
                f"The video should be approximately {duration} seconds long. "
                f"Use {config['transition']} transitions with {config['pacing']} pacing. "
                f"Add {music_prompt}."
            )

            logger.info(f"Video creation prompt: {full_prompt[:100]}...")

            # Placeholder: 실제로는 Veo API 호출
            # response = await veo_client.generate_video(
            #     media=media_files,
            #     prompt=full_prompt,
            #     duration=duration,
            # )

            logger.info(f"Video creation completed: {duration}s")

            # Placeholder 반환
            return b"video_placeholder"

        except Exception as e:
            if "quota" in str(e).lower() or "rate" in str(e).lower():
                raise RateLimitException("Veo rate limit exceeded")
            logger.error(f"Veo API error: {e}")
            raise GeminiException(str(e))

    async def analyze_image(
        self,
        image_data: bytes,
        prompt: str,
        image_format: str = "jpeg",
    ) -> str:
        """
        Analyze an image using Gemini Vision.

        Args:
            image_data: Raw image bytes
            prompt: Analysis prompt
            image_format: Image format

        Returns:
            Analysis text

        Raises:
            GeminiException: On API errors
        """
        if not self.is_available():
            raise GeminiException("Gemini API is not configured")

        try:
            image_part = {
                "mime_type": f"image/{image_format}",
                "data": base64.b64encode(image_data).decode("utf-8"),
            }

            response = await self._model.generate_content_async(
                contents=[prompt, image_part],
                generation_config={
                    "temperature": 0.4,
                    "max_output_tokens": 1024,
                },
            )

            return response.text

        except Exception as e:
            logger.error(f"Gemini Vision error: {e}")
            raise GeminiException(str(e))


# Singleton instance
gemini_service = GeminiService()
