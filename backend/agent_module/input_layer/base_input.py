from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import Optional
from datetime import datetime
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI()

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
    ageGroup: Optional[str] = '20'
    gender: Optional[str] = None
    travelStartDate: Optional[str] = None
    travelEndDate: Optional[str] = None
    departureTime: Optional[str] = None
    arrivalTime: Optional[str] = None
    numberOfTravelers: Optional[int] = None
    accommodationLocation: Optional[str] = None

# 여행 계획 저장소 (임시, 실제로는 DB 연결 필요)
travel_plans = []

@app.post("/api/travel-plans/")
async def create_travel_plan(plan_data: TravelPlanData):
    try:
        # 데이터 검증 로직은 필요에 따라 추가
        travel_plans.append(plan_data.dict())
        return {"status": "success", "message": "여행 계획이 성공적으로 저장되었습니다.", "data": plan_data}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"서버 오류: {str(e)}")

@app.get("/api/travel-plans/")
async def get_travel_plans():
    return travel_plans

# 서버 실행 테스트용
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
