import os
from dotenv import load_dotenv
load_dotenv()

from agents import Agent
from pydantic import BaseModel

from utils.prompt import AgentPromptTemplate

class NewPlanOutput(BaseModel):
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
        self.plan_guardail_agent = Agent(
            name="Plan Guardail Agent",
            instructions="Check if type of the output is JSON format",
            model="gpt-4o-mini",
            output_type=NewPlanOutput
        )
        self.final_base_plan = dict()
        self.final_base_plan_prompt = ""

    def set_base_planner_agent(self):
        self.base_planner_agent = Agent(
            name="Base Planner Agent",
            instructions=self.final_base_plan_prompt,
            model="gpt-4o-mini",
            tools=[]
        )
        
    def set_prompt_from_data(self, travel_plan, user_preference=None):
        """
        여행 계획 데이터와 사용자 선호도 정보로부터 프롬프트를 생성하고 설정합니다.
        
        Args:
            travel_plan (dict): 여행 계획 데이터
            user_preference (dict, optional): 사용자 선호도 데이터
        """
        # AgentPromptTemplate에서 프롬프트 생성
        self.final_base_plan_prompt = AgentPromptTemplate.create_final_prompt(
            travel_plan, 
            user_preference
        )
        # 여행 계획 정보 저장
        self.final_base_plan = travel_plan
        
    def generate_travel_plan(self):
        """
        설정된 프롬프트를 기반으로 여행 계획을 생성합니다.
        
        Returns:
            dict: 생성된 여행 계획 데이터
        """
        # 기본 에이전트 설정 (프롬프트가 설정된 경우에만)
        if not self.final_base_plan_prompt:
            raise ValueError("프롬프트가 설정되지 않았습니다. set_prompt_from_data()를 먼저 호출해주세요.")
            
        # 에이전트 설정
        self.set_base_planner_agent()
        
        # 여행 계획 생성 (여기서는 간단히 에이전트를 실행하는 방식)
        # 실제 구현에서는 이 부분에 에이전트를 실행하고 결과를 처리하는 코드가 들어갑니다.
        # 아래는 예시 코드입니다.
        try:
            # 에이전트 실행 예시
            # response = self.base_planner_agent.generate()
            # 실제 구현이 필요합니다
            
            # 임시 반환값 (테스트용)
            return {
                "status": "success",
                "message": "여행 계획이 생성되었습니다.",
                "prompt": self.final_base_plan_prompt,
                "plan_data": self.final_base_plan
            }
        except Exception as e:
            return {
                "status": "error",
                "message": f"여행 계획 생성 중 오류가 발생했습니다: {str(e)}"
            }

