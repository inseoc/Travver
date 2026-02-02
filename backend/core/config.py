"""Application configuration using Pydantic Settings."""

import json
from functools import lru_cache
from typing import List
from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


def parse_list_str(value: str, default: List[str] = None) -> List[str]:
    """Parse comma-separated or JSON list string."""
    if not value:
        return default or []
    value = value.strip()
    if value.startswith("["):
        try:
            return json.loads(value)
        except json.JSONDecodeError:
            pass
    return [item.strip() for item in value.split(",") if item.strip()]


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # App
    app_name: str = "Travver API"
    environment: str = "development"

    # OpenAI
    openai_api_key: str = ""
    openai_model: str = "gpt-4o-mini"

    # Google AI (Gemini)
    google_api_key: str = ""
    gemini_api_key: str = ""
    gemini_model: str = "gemini-1.5-flash"
    gemini_image_model: str = "gemini-2.5-flash-preview-image"
    gemini_video_model: str = "veo-3.1-generate-preview"

    # Google Places API
    google_places_api_key: str = ""

    # Exchange Rate API
    exchange_rate_api_key: str = ""
    exchange_rate_base_url: str = "https://api.exchangerate-api.com/v4"

    # Server
    api_host: str = "0.0.0.0"
    api_port: int = 8000
    debug: bool = False

    # CORS - stored as string, accessed via property
    cors_origins_str: str = Field(
        default="http://localhost:3000,http://localhost:8080,*",
        validation_alias="CORS_ORIGINS"
    )

    @property
    def cors_origins(self) -> List[str]:
        """Get CORS origins as list."""
        origins = parse_list_str(
            self.cors_origins_str,
            ["http://localhost:3000", "http://localhost:8080", "*"]
        )
        # 개발 환경에서는 모든 출처 허용 (Flutter 웹 등)
        if self.environment == "development" and "*" not in origins:
            origins.append("*")
        return origins

    @property
    def effective_gemini_api_key(self) -> str:
        """Get effective Gemini API key."""
        return self.gemini_api_key or self.google_api_key

    def is_openai_configured(self) -> bool:
        """Check if OpenAI API is configured."""
        return bool(self.openai_api_key and self.openai_api_key.startswith("sk-"))

    def is_google_configured(self) -> bool:
        """Check if Google API is configured."""
        return bool(self.google_api_key)


@lru_cache
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()


settings = get_settings()
