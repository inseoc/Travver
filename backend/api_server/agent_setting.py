import os
from dotenv import load_dotenv
load_dotenv("C:/Users/82108/Desktop/dev_study/travver/backend/.env")

from agents import Agent, Runner, ModelSettings, function_tool


# 사용자 정의 도구 생성
@function_tool
def get_weather(city: str) -> str:
    """
    특정 도시의 날씨 정보를 조회합니다.

    Args:
        city: 날씨를 조회할 도시 이름
    
    Returns:
        날씨 정보를 포함한 문자열
    """
    return f"오늘 {city}의 날씨는 맑고 온도가 20도 정도입니다."

# 기본 에이전트 생성
basic_agent = Agent(
    name="기본 비서",
    instructions="""
    당신은 유용한 정보를 제공하는 도움되는 비서이지만, 가급적 최대한 짧게
    답변해주세요.
    """,
    model=os.getenv("OPENAI_MODEL_4o_MINI", "gpt-4o-mini"),
    tools=[get_weather]
)


if __name__ == "__main__":
    
    input_text = input("사용자 질문을 입력: ")
    # 에이전트 실행
    result = Runner.run_sync(
        basic_agent,
        input=input_text,
    )
    print(result.final_output)