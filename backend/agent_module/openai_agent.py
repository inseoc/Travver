import os
from dotenv import load_dotenv
load_dotenv()

from agents import Agent
from pydantic import BaseModel

from utils.prompt import AgentPrompt

class NewPlanOutput(BaseModel):
    travel_plan: str
    ageGroup: str
    gender: str
    travelStartDate: str
    travelEndDate: str
    departureTime: str
    arrivalTime: str
    numberOfTravelers: int
    accommodationLocation: str
    days: str
    start_date: str
    end_date: str


class TravelAgent:
    def __init__(self):
        self.plan_guardail_agnet = Agent(
            name="Plan Guardail Agent",
            instructions="Check if type of the output is JSON format",
            model="gpt-4o-mini",
            output_type=NewPlanOutput
        )
        
        self.base_planner_agent = Agent(
            name="Base Planner Agent",
            instructions=AgentPrompt.generate_base_plan_prompt,
            model="gpt-4o-mini",
            tools=[]
        )
        
        self.trigger_agent = Agent(
            name="Trigger Agent",
            instructions="You determine which agent to use based on the user's basic information.",
            model="gpt-4o-mini",
            handoffs=[]
        )




agent = Agent(
    name="Math Tutor",
    instructions="You provide help with math problems. Explain your reasoning at each step and include examples",
)
