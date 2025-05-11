import os
from dotenv import load_dotenv
load_dotenv("C:/Users/82108/Desktop/dev_study/travver/backend/.env")

from pydantic import BaseModel
from typing import List, Dict, Any

from agents import (
    Agent,
    GuardrailFunctionOutput,
    OutputGuardrailTripwireTriggered,
    RunContextWrapper,
    Runner,
    output_guardrail,
)


class DayActivity(BaseModel):
    time: str
    location: str
    description: str


class BasePlanOutput(BaseModel):
    travel_plan: Dict[str, List[DayActivity]]
    is_plan: bool


class TravelAgent:
    def __init__(self):
        self.plan_guardrail_agent = Agent(
            name="Plan Guardrail Checker",
            instructions="Check if type of the output is JSON format",
            model=os.getenv("OPENAI_MODEL_NAME"),
            output_type=BasePlanOutput
        )

    @output_guardrail
    async def plan_guardrail(self, 
                             ctx: RunContextWrapper, 
                             output: BasePlanOutput) -> GuardrailFunctionOutput:

        result = await Runner.run(self.plan_guardrail_agent, 
                                  output.response,
                                  context=ctx.context)
        
        return GuardrailFunctionOutput(
            output_info=result.final_output,
            tripwire_triggered=result.final_output.is_plan
        )

    async def get_base_plan(self) -> Agent:
        # return Agent(
        #     name="Base Plan Agent",
        #     instructions="Generate a base plan for the travel plan",
        #     model=os.getenv("OPENAI_MODEL_NAME"),
        #     output_guardrails=[self.plan_guardrail],
        #     output_type=BasePlanOutput
        # )
        return Agent(
            name="Base Plan Agent",
            instructions="Generate a base plan for the travel plan",
            model=os.getenv("OPENAI_MODEL_NAME")
        )
