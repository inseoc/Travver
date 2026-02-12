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
                model=settings.gemini_image_model,
                contents=[prompt, input_image],
            )

            # 응답에서 이미지 추출
            for part in response.parts:
                if part.inline_data is not None:
                    # inline_data에서 직접 bytes 추출
                    result_bytes = part.inline_data.data
                    result_mime = part.inline_data.mime_type or "image/jpeg"

                    # 요청된 포맷과 다르면 PIL로 변환
                    requested_mime = f"image/{image_format.lower()}"
                    if result_mime != requested_mime:
                        try:
                            from PIL import Image as PILImage
                            img = PILImage.open(io.BytesIO(result_bytes))
                            output_buffer = io.BytesIO()
                            pil_format = "JPEG" if image_format.lower() in ["jpeg", "jpg"] else image_format.upper()
                            img.save(output_buffer, format=pil_format)
                            result_bytes = output_buffer.getvalue()
                        except Exception:
                            pass  # 변환 실패 시 원본 bytes 사용

                    logger.info(f"Photo decoration completed for style: {style}")
                    return result_bytes

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

        사용자가 업로드한 이미지를 레퍼런스로 사용하여 image-to-video 모드로 생성합니다.

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
            logger.info(f"Creating video: style={style}, music={music}, duration={duration}s, aspect_ratio={aspect_ratio}, files={len(media_files)}")

            # 1. 업로드된 이미지에서 레퍼런스 이미지 추출 (JPEG bytes)
            reference_image_bytes = self._extract_reference_image(media_files)

            # 2. 이미지 분석으로 실제 내용 파악
            image_description = await self._analyze_media_for_video(media_files)
            logger.info(f"Image analysis result: {image_description[:150]}...")

            # 3. 이미지 기반 프롬프트 생성
            if reference_image_bytes is not None:
                full_prompt = (
                    f"Based on this reference image, create a video that features "
                    f"the SAME people, location, and scene shown in the photo. "
                    f"The image shows: {image_description}. "
                    f"Maintain the exact appearance of the people and setting. "
                    f"{config['prompt']} "
                    f"The video should be approximately {duration} seconds long. "
                    f"Use {config['transition']} transitions with {config['pacing']} pacing. "
                    f"Add {music_prompt}."
                )
            else:
                full_prompt = (
                    f"Create a travel video showing: {image_description}. "
                    f"{config['prompt']} "
                    f"The video should be approximately {duration} seconds long. "
                    f"Use {config['transition']} transitions with {config['pacing']} pacing. "
                    f"Add {music_prompt}."
                )

            logger.info(f"Video creation prompt: {full_prompt[:200]}...")

            # 4. Veo 3.1 API 호출 (image-to-video 모드)
            veo_config = self._veo_types.GenerateVideosConfig(
                aspect_ratio=aspect_ratio,
                person_generation="allow_adult",
            )

            if reference_image_bytes is not None:
                # types.Image에 bytesBase64Encoded + mimeType 포함하여 전달
                reference_image = self._veo_types.Image(
                    image_bytes=reference_image_bytes,
                    mime_type="image/jpeg",
                )
                logger.info("Using image-to-video mode with reference image")
                operation = self._veo_client.models.generate_videos(
                    model=settings.gemini_video_model,
                    prompt=full_prompt,
                    image=reference_image,
                    config=veo_config,
                )
            else:
                logger.info("No valid reference image found, using text-to-video mode")
                operation = self._veo_client.models.generate_videos(
                    model=settings.gemini_video_model,
                    prompt=full_prompt,
                    config=veo_config,
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
            video_bytes = generated_video.video.video_bytes

            logger.info(f"Video creation completed: {duration}s, aspect_ratio={aspect_ratio}")
            return video_bytes

        except GeminiException:
            raise
        except Exception as e:
            if "quota" in str(e).lower() or "rate" in str(e).lower():
                raise RateLimitException("Veo rate limit exceeded")
            logger.error(f"Veo API error: {e}")
            raise GeminiException(str(e))

    def _extract_reference_image(self, media_files: list[bytes]) -> Optional[bytes]:
        """
        업로드된 파일에서 첫 번째 유효한 이미지를 JPEG bytes로 추출합니다.

        Returns:
            JPEG image bytes or None
        """
        from PIL import Image

        for file_bytes in media_files:
            try:
                img = Image.open(io.BytesIO(file_bytes))
                img.load()  # 이미지가 유효한지 확인
                logger.info(f"Reference image found: {img.size}, mode={img.mode}")
                # RGB로 변환 (RGBA, P 등 다른 모드 대응)
                if img.mode not in ("RGB",):
                    img = img.convert("RGB")
                # JPEG bytes로 변환하여 일관된 포맷 보장
                buf = io.BytesIO()
                img.save(buf, format="JPEG", quality=90)
                return buf.getvalue()
            except Exception:
                continue

        logger.warning("No valid image found in uploaded media")
        return None

    async def _analyze_media_for_video(self, media_files: list[bytes]) -> str:
        """
        업로드된 이미지들을 Gemini Vision으로 분석하여
        영상 프롬프트에 사용할 설명을 생성합니다.
        """
        from PIL import Image

        try:
            prompt_text = (
                "Analyze these travel photos and describe them for video creation. "
                "Focus on: "
                "1) The people: their appearance, clothing, and what they're doing. "
                "2) The location: scenery, landmarks, environment. "
                "3) The mood and atmosphere. "
                "Be specific and concise. Respond in English in 2-3 sentences."
            )

            contents = [prompt_text]

            images_added = 0
            for file_bytes in media_files[:5]:
                try:
                    img = Image.open(io.BytesIO(file_bytes))
                    img.load()
                    if img.mode not in ("RGB",):
                        img = img.convert("RGB")
                    contents.append(img)
                    images_added += 1
                except Exception as img_err:
                    logger.debug(f"Skipping non-image file: {img_err}")
                    continue

            if images_added == 0:
                logger.warning("No valid images found for analysis")
                return "travel scenes and moments"

            logger.info(f"Analyzing {images_added} images with Gemini Vision")

            # decorate_photo와 동일한 모델 사용 (이미지 처리 확인됨)
            response = self._veo_client.models.generate_content(
                model=settings.gemini_image_model,
                contents=contents,
            )

            description = response.text or "travel scenes and moments"
            logger.info(f"Image analysis completed: {description[:100]}...")
            return description.strip()

        except Exception as e:
            logger.warning(f"Image analysis for video failed: {type(e).__name__}: {e}")
            return "travel scenes and moments"

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
                    "max_output_tokens": 1024,
                },
            )

            return response.text

        except Exception as e:
            logger.error(f"Gemini Vision error: {e}")
            raise GeminiException(str(e))


# Singleton instance
gemini_service = GeminiService()
