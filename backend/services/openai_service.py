"""OpenAI API service with retry logic and error handling."""

import json
from typing import Any, AsyncGenerator, Callable, Dict, List, Optional
from openai import AsyncOpenAI, OpenAIError
from tenacity import (
    retry,
    stop_after_attempt,
    wait_exponential,
    retry_if_exception_type,
)

from core.config import settings
from core.logger import logger
from core.exceptions import OpenAIException, RateLimitException


class OpenAIService:
    """OpenAI API 서비스."""

    def __init__(self):
        """Initialize OpenAI client."""
        if not settings.is_openai_configured():
            logger.warning("OpenAI API key not configured")
            self.client = None
        else:
            self.client = AsyncOpenAI(api_key=settings.openai_api_key)
        self.model = settings.openai_model

    def is_available(self) -> bool:
        """Check if service is available."""
        return self.client is not None

    @retry(
        stop=stop_after_attempt(3),
        wait=wait_exponential(multiplier=1, min=2, max=10),
        retry=retry_if_exception_type(OpenAIError),
        before_sleep=lambda retry_state: logger.warning(
            f"OpenAI API retry attempt {retry_state.attempt_number}"
        ),
    )
    async def chat_completion(
        self,
        messages: List[Dict[str, str]],
        tools: Optional[List[Dict[str, Any]]] = None,
        tool_choice: Optional[str] = "auto",
        temperature: float = 0.7,
        max_tokens: int = 4096,
    ) -> Dict[str, Any]:
        """
        Create a chat completion with optional function calling.

        Args:
            messages: List of message dicts with role and content
            tools: Optional list of tool definitions for function calling
            tool_choice: How to select tools ("auto", "none", or specific)
            temperature: Sampling temperature (0-2)
            max_tokens: Maximum tokens in response

        Returns:
            OpenAI response dict

        Raises:
            OpenAIException: On API errors
        """
        if not self.is_available():
            raise OpenAIException("OpenAI API is not configured")

        try:
            kwargs = {
                "model": self.model,
                "messages": messages,
                "temperature": temperature,
                "max_tokens": max_tokens,
            }

            if tools:
                kwargs["tools"] = tools
                kwargs["tool_choice"] = tool_choice

            logger.debug(f"OpenAI request: {len(messages)} messages, tools: {bool(tools)}")

            response = await self.client.chat.completions.create(**kwargs)

            logger.debug(f"OpenAI response: {response.usage.total_tokens} tokens used")

            return {
                "content": response.choices[0].message.content,
                "tool_calls": [
                    {
                        "id": tc.id,
                        "function": {
                            "name": tc.function.name,
                            "arguments": tc.function.arguments,
                        },
                    }
                    for tc in (response.choices[0].message.tool_calls or [])
                ],
                "finish_reason": response.choices[0].finish_reason,
                "usage": {
                    "prompt_tokens": response.usage.prompt_tokens,
                    "completion_tokens": response.usage.completion_tokens,
                    "total_tokens": response.usage.total_tokens,
                },
            }

        except OpenAIError as e:
            if "rate_limit" in str(e).lower():
                raise RateLimitException("OpenAI rate limit exceeded")
            logger.error(f"OpenAI API error: {e}")
            raise OpenAIException(str(e))

    async def chat_completion_stream(
        self,
        messages: List[Dict[str, str]],
        temperature: float = 0.7,
        max_tokens: int = 4096,
    ) -> AsyncGenerator[str, None]:
        """
        Create a streaming chat completion.

        Args:
            messages: List of message dicts
            temperature: Sampling temperature
            max_tokens: Maximum tokens

        Yields:
            Content chunks as they arrive

        Raises:
            OpenAIException: On API errors
        """
        if not self.is_available():
            raise OpenAIException("OpenAI API is not configured")

        try:
            stream = await self.client.chat.completions.create(
                model=self.model,
                messages=messages,
                temperature=temperature,
                max_tokens=max_tokens,
                stream=True,
            )

            async for chunk in stream:
                if chunk.choices[0].delta.content:
                    yield chunk.choices[0].delta.content

        except OpenAIError as e:
            logger.error(f"OpenAI streaming error: {e}")
            raise OpenAIException(str(e))

    async def execute_with_tools(
        self,
        messages: List[Dict[str, str]],
        tools: List[Dict[str, Any]],
        tool_handlers: Dict[str, Callable],
        max_iterations: int = 5,
    ) -> Dict[str, Any]:
        """
        Execute chat completion with automatic tool calling loop.

        Args:
            messages: Initial messages
            tools: Tool definitions
            tool_handlers: Dict mapping tool names to handler functions
            max_iterations: Maximum tool call iterations

        Returns:
            Final response with all tool results

        Raises:
            OpenAIException: On API errors
        """
        current_messages = messages.copy()
        tools_used = []
        iteration = 0

        while iteration < max_iterations:
            iteration += 1
            logger.debug(f"Tool execution iteration {iteration}")

            response = await self.chat_completion(
                messages=current_messages,
                tools=tools,
                tool_choice="auto" if iteration < max_iterations else "none",
            )

            # If no tool calls, return the response
            if not response["tool_calls"]:
                return {
                    "content": response["content"],
                    "tools_used": tools_used,
                    "iterations": iteration,
                }

            # Process tool calls
            assistant_message = {
                "role": "assistant",
                "content": response["content"] or "",
                "tool_calls": [
                    {
                        "id": tc["id"],
                        "type": "function",
                        "function": tc["function"],
                    }
                    for tc in response["tool_calls"]
                ],
            }
            current_messages.append(assistant_message)

            # Execute each tool call
            for tool_call in response["tool_calls"]:
                func_name = tool_call["function"]["name"]
                func_args = json.loads(tool_call["function"]["arguments"])

                logger.info(f"Executing tool: {func_name} with args: {func_args}")
                tools_used.append(func_name)

                if func_name in tool_handlers:
                    try:
                        result = await tool_handlers[func_name](**func_args)
                        tool_result = json.dumps(result, ensure_ascii=False)
                    except Exception as e:
                        logger.error(f"Tool execution error: {func_name} - {e}")
                        tool_result = json.dumps({"error": str(e)})
                else:
                    tool_result = json.dumps({"error": f"Unknown tool: {func_name}"})

                current_messages.append({
                    "role": "tool",
                    "tool_call_id": tool_call["id"],
                    "content": tool_result,
                })

        # Max iterations reached
        final_response = await self.chat_completion(
            messages=current_messages,
            tools=None,
        )

        return {
            "content": final_response["content"],
            "tools_used": tools_used,
            "iterations": iteration,
        }


# Singleton instance
openai_service = OpenAIService()
