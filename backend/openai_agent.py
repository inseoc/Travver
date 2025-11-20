import os
import json
import asyncio
from dotenv import load_dotenv

# 경로 조정 필요시 수정
load_dotenv()

# [중요] ConfigDict 추가 임포트
from pydantic import BaseModel, Field, ConfigDict
from typing import List, Dict, Any

from agents import (
    Agent,
    GuardrailFunctionOutput,
    RunContextWrapper,
    Runner,
    output_guardrail,
)

# --- Data Models ---

# [중요] 모든 모델에 model_config = ConfigDict(extra='forbid') 추가

class DayActivity(BaseModel):
    model_config = ConfigDict(extra='forbid') # Strict Mode 필수 설정
    time: str
    location: str
    description: str

# [NEW] Dict 대신 List 구조를 위한 중간 모델
class DailyPlan(BaseModel):
    model_config = ConfigDict(extra='forbid')
    day: str = Field(description="Day identifier, e.g., 'DAY1'")
    activities: List[DayActivity]

class BasePlanOutput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    # Dict[str, List]는 Strict Mode에서 지원되지 않으므로 List[DailyPlan]으로 변경
    travel_plan: List[DailyPlan] = Field(description="List of daily plans")
    is_plan: bool

class DailyDetailOutput(BaseModel):
    model_config = ConfigDict(extra='forbid')
    activities: List[DayActivity]

# --- Agent Class ---

class TravelAgent:
    def __init__(self):
        self.model_name = os.getenv("OPENAI_MODEL_NAME", "gpt-4-turbo-preview") 

        self.plan_guardrail_agent = Agent(
            name="Plan Guardrail Checker",
            instructions="Check if type of the output is JSON format",
            model=self.model_name,
            output_type=BasePlanOutput
        )

        self.detail_guardrail_agent = Agent(
            name="Detail Guardrail Checker",
            instructions="Check if the daily detail output is a valid list of activities.",
            model=self.model_name,
            output_type=DailyDetailOutput
        )

    @output_guardrail
    async def plan_guardrail(self, ctx: RunContextWrapper, output: BasePlanOutput) -> GuardrailFunctionOutput:
        result = await Runner.run(self.plan_guardrail_agent, output.response, context=ctx.context)
        return GuardrailFunctionOutput(
            output_info=result.final_output,
            tripwire_triggered=result.final_output.is_plan
        )

    @output_guardrail
    async def detail_guardrail(self, ctx: RunContextWrapper, output: DailyDetailOutput) -> GuardrailFunctionOutput:
        return GuardrailFunctionOutput(
            output_info=output,
            tripwire_triggered=True 
        )

    async def get_base_plan(self) -> Agent:
        """(구버전 API용) 텍스트 기반 에이전트"""
        return Agent(
            name="Base Plan Agent",
            instructions="Generate a base plan for the travel plan",
            model=self.model_name
        )

    async def get_base_plan_agent_structured(self) -> Agent:
        """(신버전 API용) 구조화된 출력 에이전트"""
        return Agent(
            name="Base Plan Agent Structured",
            instructions="Generate a base skeleton plan for the travel.",
            model=self.model_name,
            output_type=BasePlanOutput # 위에서 정의한 Strict Schema 모델 사용
        )

    async def get_daily_detail_agent(self) -> Agent:
        return Agent(
            name="Daily Detail Agent",
            instructions="Expand the base plan for a specific day into a detailed itinerary.",
            model=self.model_name,
            output_type=DailyDetailOutput
        )

    # --- Orchestration Logic ---

    async def generate_comprehensive_plan(self, travel_info: Dict[str, Any], prompt_template) -> Dict[str, Any]:
        """
        1. Base Plan 생성 (List 구조)
        2. 각 Day별 병렬 상세화
        3. 결과 병합 (Dict 구조로 변환하여 반환)
        """
        
        # 1. Base Plan 생성
        print("--- Generating Base Plan ---")
        # [변경] 새로운 구조화된 프롬프트 사용
        base_prompt = prompt_template.generate_base_plan_structured_prompt.format(**travel_info)
        base_agent = await self.get_base_plan_agent_structured()
        
        base_run_result = await Runner.run(base_agent, base_prompt)
        
        # Pydantic 모델 결과 획득
        base_plan_output = base_run_result.final_output
        
        # List[DailyPlan] 형태의 데이터를 사용하여 병렬 처리 준비
        print(f"Base Plan Generated with {len(base_plan_output.travel_plan)} days.")

        # 2. 각 Day별 상세 일정 생성 (병렬 처리)
        detail_agent = await self.get_daily_detail_agent()
        tasks = []
        day_keys = [] # 순서 유지를 위한 키 저장

        # Base Plan은 이제 List 형태이므로 반복문 수정
        for daily_plan in base_plan_output.travel_plan:
            day_key = daily_plan.day
            activities = daily_plan.activities
            
            day_keys.append(day_key)
            
            # 상세화 프롬프트 구성
            activities_json = json.dumps([a.model_dump() for a in activities], ensure_ascii=False)

            detail_prompt = prompt_template.daily_detail_plan_prompt.format(
                day_key=day_key,
                base_day_plan=activities_json,
                preference=travel_info.get('preference', ''),
                numberOfTravelers=travel_info.get('numberOfTravelers', 1)
            )
            
            # 비동기 태스크 추가
            tasks.append(Runner.run(detail_agent, detail_prompt))

        print(f"--- Generating Details for {len(tasks)} days in parallel ---")
        
        # 병렬 실행
        if tasks:
            results = await asyncio.gather(*tasks, return_exceptions=True)
        else:
            results = []

        # 3. 결과 병합 (List -> Frontend 호환 Dict 변환)
        final_plan = {}
        
        # 원본 Base Plan을 백업용으로 Dict 변환
        base_plan_dict_fallback = {item.day: [act.model_dump() for act in item.activities] for item in base_plan_output.travel_plan}

        for day_key, result in zip(day_keys, results):
            if isinstance(result, Exception):
                print(f"Error detailed plan for {day_key}: {result}")
                # 실패 시 기본 플랜 사용
                final_plan[day_key] = base_plan_dict_fallback.get(day_key, [])
            else:
                try:
                    # 결과 파싱
                    if hasattr(result.final_output, 'activities'):
                        final_plan[day_key] = [
                            act.model_dump() for act in result.final_output.activities
                        ]
                    else:
                        # Fallback text parsing logic if needed
                        raw_text = result.new_items[0].raw_item.content[0].text
                        import re
                        json_match = re.search(r'```(?:json)?\s*\n?(.*?)```', raw_text, re.DOTALL)
                        json_str = json_match.group(1).strip() if json_match else raw_text
                        final_plan[day_key] = json.loads(json_str)
                except Exception as e:
                    print(f"Parsing error for {day_key}: {e}")
                    final_plan[day_key] = base_plan_dict_fallback.get(day_key, [])
        
        # Base Plan의 메타데이터는 필요하다면 여기서 추가 (현재 로직상 필요 없음)
        
        return final_plan