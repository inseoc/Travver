"""Custom exceptions for the application."""

from typing import Any, Optional


class TravverException(Exception):
    """Base exception for Travver application."""

    def __init__(
        self,
        message: str,
        code: str = "UNKNOWN_ERROR",
        details: Optional[Any] = None,
    ):
        self.message = message
        self.code = code
        self.details = details
        super().__init__(self.message)


class AIServiceException(TravverException):
    """Exception for AI service errors."""

    def __init__(self, message: str, details: Optional[Any] = None):
        super().__init__(message, code="AI_SERVICE_ERROR", details=details)


class OpenAIException(AIServiceException):
    """Exception for OpenAI API errors."""

    def __init__(self, message: str, details: Optional[Any] = None):
        super().__init__(f"OpenAI Error: {message}", details=details)
        self.code = "OPENAI_ERROR"


class GeminiException(AIServiceException):
    """Exception for Google Gemini API errors."""

    def __init__(self, message: str, details: Optional[Any] = None):
        super().__init__(f"Gemini Error: {message}", details=details)
        self.code = "GEMINI_ERROR"


class ToolExecutionException(TravverException):
    """Exception for tool execution errors."""

    def __init__(self, tool_name: str, message: str, details: Optional[Any] = None):
        super().__init__(
            f"Tool '{tool_name}' failed: {message}",
            code="TOOL_EXECUTION_ERROR",
            details=details,
        )
        self.tool_name = tool_name


class ValidationException(TravverException):
    """Exception for validation errors."""

    def __init__(self, message: str, details: Optional[Any] = None):
        super().__init__(message, code="VALIDATION_ERROR", details=details)


class RateLimitException(TravverException):
    """Exception for rate limit errors."""

    def __init__(self, message: str = "Rate limit exceeded", retry_after: Optional[int] = None):
        super().__init__(message, code="RATE_LIMIT_ERROR", details={"retry_after": retry_after})
        self.retry_after = retry_after
