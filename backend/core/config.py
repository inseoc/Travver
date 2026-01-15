"""Application configuration using Pydantic Settings."""

from functools import lru_cache
from typing import List
from pydantic_settings import BaseSettings, SettingsConfigDict


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
    openai_model: str = "gpt-4-turbo-preview"  # 실제로는 gpt-5.2 사용 예정

    # Google AI (Gemini)
    google_api_key: str = ""
    gemini_api_key: str = ""  # Alias for google_api_key
    gemini_model: str = "gemini-pro-vision"  # Gemini Nano Banana Pro 예정
    veo_model: str = "veo-3.1"  # Veo 3.1 예정

    # Google Places API
    google_places_api_key: str = ""

    # Exchange Rate API
    exchange_rate_api_key: str = ""
    exchange_rate_base_url: str = "https://api.exchangerate-api.com/v4"

    # Server
    api_host: str = "0.0.0.0"
    api_port: int = 8000
    debug: bool = False

    # CORS
    cors_origins: List[str] = ["http://localhost:3000", "http://localhost:8080", "*"]

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
