import pytz

from pydantic import BaseModel
from typing import Optional, List, Dict, Any
from datetime import datetime, timedelta

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from agents import Agent, Runner

from openai_agent import TravelAgent
from utils.prompt import AgentPromptTemplate


app = FastAPI(title="Travver API", description="여행 계획 정보를 관리하는 API")

# 한국 시간대 설정
KST = pytz.timezone('Asia/Seoul')

# 날짜 포맷 함수 - 한국어 형식으로 변환
def format_korean_date(date_str: str) -> str:
    if not date_str:
        return None
    try:
        # ISO 형식 문자열을 datetime으로 변환
        date_obj = datetime.fromisoformat(date_str.replace("Z", "+00:00"))
        # 한국 시간대로 변환
        kr_date = date_obj.astimezone(KST)
        # 한국어 형식으로 포맷팅 (예: 2024년 7월 1일)
        return kr_date.strftime("%Y년 %m월 %d일")
    except ValueError:
        return date_str

# CORS 설정 - 모든 출처 허용 (개발용)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 실제 프로덕션에서는 특정 도메인만 허용하도록 수정 필요
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# 여행 계획 데이터 모델
class TravelPlanData(BaseModel):
    ageGroup: Optional[str] = None
    gender: Optional[str] = None
    travelStartDate: Optional[str] = None
    travelEndDate: Optional[str] = None
    kor_departureTime: Optional[str] = None
    jpn_departureTime: Optional[str] = None
    numberOfTravelers: Optional[int] = None
    accommodationLocation: Optional[str] = None

    class Config:
        json_schema_extra = {
            "example": {
                "ageGroup": "20대",
                "gender": "male",
                "travelStartDate": "2024-07-01T00:00:00.000Z",
                "travelEndDate": "2024-07-05T00:00:00.000Z",
                "kor_departureTime": "09:00",
                "jpn_departureTime": "18:00",
                "numberOfTravelers": 2,
                "accommodationLocation": "오사카 중앙역 근처"
            }
        }

# 여행 선호도 데이터 모델
class TravelPreferenceData(BaseModel):
    userPreference: str  # 사용자가 입력한 여행 선호도 텍스트

    class Config:
        json_schema_extra = {
            "example": {
                "userPreference": "쇼핑과 맛집 탐방을 좋아하고, 유명 관광지보다는 현지인들이 많이 가는 곳을 선호합니다."
            }
        }

# 계획 생성 요청 모델
class GeneratePlanRequest(BaseModel):
    ageGroup: Optional[str] = None
    gender: Optional[str] = None
    travelStartDate: Optional[str] = None
    travelEndDate: Optional[str] = None
    kor_departureTime: Optional[str] = None
    jpn_departureTime: Optional[str] = None
    numberOfTravelers: Optional[int] = None
    accommodationLocation: Optional[str] = None
    preference: Optional[str] = None
    days: Optional[str] = None
    start_date: Optional[str] = None
    end_date: Optional[str] = None

# 활동 항목 모델
class ActivityItem(BaseModel):
    time: str
    title: str
    description: Optional[str] = None

# 일별 일정 모델
class DayItinerary(BaseModel):
    date: str
    activities: List[ActivityItem]

# 수정 요청 모델
class EditRequestModel(BaseModel):
    planId: str
    editRequest: str

# 프롬프트 요청 모델
class PromptRequestData(BaseModel):
    plan_id: int  # 여행 계획 ID
    preference_id: Optional[int] = None  # 선호도 ID (선택 사항)

    class Config:
        json_schema_extra = {
            "example": {
                "plan_id": 0,
                "preference_id": 0
            }
        }

# 여행 계획 저장소 (임시, 실제로는 DB 연결 필요)
travel_plans = []
# 여행 선호도 저장소 (임시, 실제로는 DB 연결 필요)
travel_preferences = []
# 생성된 여행 계획 저장소
generated_plans = []

# 여행 에이전트 초기화
travel_agent = TravelAgent()


@app.get("/root")
async def root():
    return JSONResponse(
        content={"message": "Travver API가 정상적으로 실행 중입니다."},
        headers={"Content-Type": "application/json; charset=utf-8"}
    )


@app.post("/api/travel-plans/")
async def create_travel_plan(plan_data: TravelPlanData):
    """
    새로운 여행 계획을 생성합니다.
    
    클라이언트에서 제공된 여행 정보를 서버에 저장합니다.
    """
    global travel_plan

    try:
        # 데이터 검증 로직은 필요에 따라 추가
        travel_plan = plan_data.model_dump()
        
        # 현재 시간 추가 (한국 시간)
        now = datetime.now(KST)
        travel_plan["created_at"] = now.strftime("%Y-%m-%dT%H:%M:%S%z")        
        # 여행 일수 계산 및 날짜 변환 (실제 구현에서는 날짜 검증 필요)
        if travel_plan["travelStartDate"] and travel_plan["travelEndDate"]:
            try:
                start_date = datetime.fromisoformat(travel_plan["travelStartDate"].replace("Z", "+00:00"))
                end_date = datetime.fromisoformat(travel_plan["travelEndDate"].replace("Z", "+00:00"))
                
                # 한국 시간대로 변환
                kr_start_date = start_date.astimezone(KST)
                kr_end_date = end_date.astimezone(KST)
                
                # 일수 계산
                days = (end_date - start_date).days
                travel_plan["days"] = f"{days}박 {days + 1}일"
                
                # 한국어 형식 날짜 추가
                travel_plan["start_date"] = kr_start_date.strftime("%Y년 %m월 %d일")
                travel_plan["end_date"] = kr_end_date.strftime("%Y년 %m월 %d일")
                
            except ValueError as e:
                print(f"날짜 변환 오류: {e}")
        
        """
        travel_plan = {
            'ageGroup': '20대', 
            'gender': 'male', 
            'travelStartDate': '2025-04-08T00:00:00.000', 
            'travelEndDate': '2025-04-10T00:00:00.000', 
            'kor_departureTime': '22:31', 
            'jpn_departureTime': '16:31', 
            'numberOfTravelers': 2, 
            'accommodationLocation': '', 
            'created_at': '2025-04-02T22:31:29+0900', 
            'days': '2박 3일', 
            'start_date': '2025년 04월 08일', 
            'end_date': '2025년 04월 10일'
        }
        """
        
        # 응답 헤더에 UTF-8 인코딩 명시
        return JSONResponse(
            content={
                "status": "success", 
                "message": "여행 계획이 성공적으로 저장되었습니다.", 
                "data": travel_plan
            },
            headers={"Content-Type": "application/json; charset=utf-8"}
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"서버 오류: {str(e)}")


@app.post("/api/travel-plans/preferences")
async def add_travel_preference(preference_data: TravelPreferenceData):
    """
    여행 계획에 사용자의 선호도 정보를 추가합니다.
    
    클라이언트에서 제공된 여행 계획 데이터와 사용자 선호도 텍스트를 저장합니다.
    """
    global travel_plan

    try:
        # 데이터 검증 로직은 필요에 따라 추가
        preference = preference_data.model_dump()
        
        travel_preferences.append(preference)
        travel_plan['preference'] = preference['userPreference']
        
        # 응답 헤더에 UTF-8 인코딩 명시
        return JSONResponse(
            content={
                "status": "success", 
                "message": "여행 선호도가 성공적으로 저장되었습니다.", 
                "data": preference
            },
            headers={"Content-Type": "application/json; charset=utf-8"}
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"서버 오류: {str(e)}")


@app.post("/api/generate-base-plan")
async def generate_travel_plan(plan_data: Dict[str, Any]):
    """
    AI를 사용하여 여행 계획을 생성합니다.
    
    사용자의 여행 정보와 선호도를 기반으로 상세한 여행 일정을 생성합니다.
    """
    try:
        # 기존 여행 계획 데이터 확인
        if not plan_data:
            raise HTTPException(status_code=400, detail="여행 계획 데이터가 필요합니다.")
        
        base_plan_prompt = AgentPromptTemplate.generate_base_plan_prompt.format(**travel_plan)
        print(base_plan_prompt)





        # 생성된 계획 저장
        generated_plans.append(generated_plan)
        
        return JSONResponse(
            content={
                "status": "success",
                "message": "여행 계획이 성공적으로 생성되었습니다.",
                "data": generated_plan
            },
            headers={"Content-Type": "application/json; charset=utf-8"}
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"서버 오류: {str(e)}")


@app.post("/api/plan/edit-request")
async def request_plan_edit(edit_request: EditRequestModel):
    """
    생성된 여행 계획에 대한 수정 요청을 처리합니다.
    
    사용자가 요청한 수정 사항을 AI 에이전트에 전달하여 계획을 업데이트합니다.
    """
    try:
        # 수정 요청 처리 로직
        # 실제로는 여기서 AI 에이전트를 호출하여 계획 수정
        
        return JSONResponse(
            content={
                "status": "success",
                "message": "수정 요청이 접수되었습니다. 잠시 후 업데이트된 계획을 확인하세요.",
                "requestId": "edit-" + datetime.now(KST).strftime("%Y%m%d%H%M%S")
            },
            headers={"Content-Type": "application/json; charset=utf-8"}
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"서버 오류: {str(e)}")


# 서버 실행 테스트용
if __name__ == "__main__":
    import uvicorn
    
    uvicorn.run(app, host="0.0.0.0", port=1234) 