"""Google Gemini API service for image and video generation."""

import base64
import io
import time
from typing import Any, Optional, Literal

from core.config import settings
from core.logger import logger
from core.exceptions import GeminiException, RateLimitException


class GeminiService:
    """Google Gemini API 서비스 (Lazy Loading)."""

    def __init__(self):
        """Initialize Gemini client."""
        self._genai = None
        self._model = None
        self._veo_client = None
        self._veo_types = None
        self._initialized = False
        self._veo_initialized = False
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

    def _ensure_veo_initialized(self):
        """Lazy initialization of Veo client for video generation."""
        if self._veo_initialized:
            return

        if not self._configured:
            return

        try:
            from google import genai
            from google.genai import types
            self._veo_client = genai.Client(api_key=settings.google_api_key)
            self._veo_types = types
            self._veo_initialized = True
            logger.info("Veo service initialized successfully")
        except ImportError:
            logger.warning("google-genai not installed for Veo")
        except Exception as e:
            logger.error(f"Failed to initialize Veo: {e}")

    def is_available(self) -> bool:
        """Check if service is available."""
        if not self._configured:
            return False
        self._ensure_initialized()
        return self._initialized

    def is_image_gen_available(self) -> bool:
        """Check if image generation service is available."""
        if not self._configured:
            return False
        self._ensure_veo_initialized()
        return self._veo_initialized

    async def decorate_photo(
        self,
        image_data: bytes,
        style: str,
        image_format: str = "jpeg",
    ) -> bytes:
        """
        Apply artistic style to a photo using Gemini 2.5 Flash Image.

        Args:
            image_data: Raw image bytes
            style: Style to apply (watercolor, oil_painting, etc.)
            image_format: Image format (jpeg, png)

        Returns:
            Transformed image bytes

        Raises:
            GeminiException: On API errors
        """
        # Genai 클라이언트 초기화
        self._ensure_veo_initialized()

        if not self._veo_initialized:
            # Fallback: 원본 이미지 반환
            logger.warning("Gemini image generation not available, returning original image")
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

            # PIL로 이미지 변환
            from PIL import Image
            input_image = Image.open(io.BytesIO(image_data))

            # Gemini 2.5 Flash Image 모델로 이미지 생성
            response = self._veo_client.models.generate_content(
                model="gemini-2.5-flash-preview-image",
                contents=[prompt, input_image],
            )

            # 응답에서 이미지 추출
            for part in response.parts:
                if part.inline_data is not None:
                    result_image = part.as_image()

                    # PIL Image를 bytes로 변환
                    output_buffer = io.BytesIO()
                    output_format = "JPEG" if image_format.lower() in ["jpeg", "jpg"] else image_format.upper()
                    result_image.save(output_buffer, format=output_format)

                    logger.info(f"Photo decoration completed for style: {style}")
                    return output_buffer.getvalue()

            # 이미지가 없으면 원본 반환
            logger.warning("No image in response, returning original image")
            return image_data

        except Exception as e:
            if "quota" in str(e).lower() or "rate" in str(e).lower():
                raise RateLimitException("Gemini rate limit exceeded")
            logger.error(f"Gemini API error: {e}")
            raise GeminiException(str(e))

    def is_veo_available(self) -> bool:
        """Check if Veo video generation service is available."""
        if not self._configured:
            return False
        self._ensure_veo_initialized()
        return self._veo_initialized

    async def create_video(
        self,
        media_files: list[bytes],
        style: str,
        music: str,
        duration: int,
        aspect_ratio: Literal["16:9", "9:16"] = "16:9",
    ) -> bytes:
        """
        Create video from media files using Gemini Veo 3.1.

        Args:
            media_files: List of media file bytes (images/videos)
            style: Video style (cinematic, vlog, highlight, album)
            music: Background music style
            duration: Target duration in seconds
            aspect_ratio: Video aspect ratio - "16:9" for landscape (default),
                         "9:16" for portrait/vertical

        Returns:
            Generated video bytes

        Raises:
            GeminiException: On API errors
        """
        # Veo 클라이언트 초기화 확인
        self._ensure_veo_initialized()

        if not self._veo_initialized:
            # Fallback: placeholder 반환
            logger.warning("Veo not available, returning placeholder")
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
            logger.info(f"Creating video: style={style}, music={music}, duration={duration}s, aspect_ratio={aspect_ratio}")

            full_prompt = (
                f"{config['prompt']} "
                f"The video should be approximately {duration} seconds long. "
                f"Use {config['transition']} transitions with {config['pacing']} pacing. "
                f"Add {music_prompt}."
            )

            logger.info(f"Video creation prompt: {full_prompt[:100]}...")

            # Veo 3.1 API 호출
            operation = self._veo_client.models.generate_videos(
                model="veo-3.1-generate-preview",
                prompt=full_prompt,
                config=self._veo_types.GenerateVideosConfig(
                    aspect_ratio=aspect_ratio,
                ),
            )

            # 비디오 생성 완료까지 폴링
            poll_interval = 10  # 초
            max_wait_time = 300  # 최대 5분 대기
            elapsed_time = 0

            while not operation.done:
                if elapsed_time >= max_wait_time:
                    raise GeminiException("Video generation timed out")
                logger.info(f"Waiting for video generation... ({elapsed_time}s elapsed)")
                time.sleep(poll_interval)
                elapsed_time += poll_interval
                operation = self._veo_client.operations.get(operation)

            # 생성된 비디오 다운로드
            generated_video = operation.response.generated_videos[0]
            self._veo_client.files.download(file=generated_video.video)

            # 비디오 바이트 데이터 반환
            video_bytes = generated_video.video.read()

            logger.info(f"Video creation completed: {duration}s, aspect_ratio={aspect_ratio}")
            return video_bytes

        except GeminiException:
            raise
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
