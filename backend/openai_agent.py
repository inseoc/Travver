from dotenv import load_dotenv
load_dotenv()

from pydantic import BaseModel

from agents import (
    Agent,
    GuardrailFunctionOutput,
    OutputGuardrailTripwireTriggered,
    RunContextWrapper,
    Runner,
    output_guardrail,
)


class BasePlanOutput(BaseModel):
    travel_plan: str
    ageGroup: str
    gender: str
    travelStartDate: str
    travelEndDate: str
    kor_departureTime: str
    jpn_departureTime: str
    numberOfTravelers: int
    accommodationLocation: str
    days: str
    start_date: str
    end_date: str


class TravelAgent:
    def __init__(self):
        self.plan_guardrail_agent = Agent(
            name="Plan Guardrail Checker",
            instructions="Check if type of the output is JSON format",
            model="gpt-4o-mini",
            output_type=BasePlanOutput
        )

    @output_guardrail
    async def plan_guardrail(self, 
                             ctx: RunContextWrapper, 
                             agent: Agent, 
                             output: BasePlanOutput) -> GuardrailFunctionOutput:

        result = await Runner.run(self.plan_guardrail_agent, 
                                  output.response,
                                  context=ctx.context)
        
        return GuardrailFunctionOutput(
            output_info=result.final_output,
            tripwire_triggered=result.final_output.travel_plan
        )

    async def get_base_plan(self):
        self.base_plan_agent = Agent(
            name="Base Plan Agent",
            instructions="Generate a base plan for the travel plan",
            model="gpt-4o-mini",
            output_guardrails=[self.plan_guardrail],
            output_type=BasePlanOutput
        )
