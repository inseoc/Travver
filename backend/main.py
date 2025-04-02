import pytz

from pydantic import BaseModel
from typing import Optional
from datetime import datetime

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from fastapi.exceptions import RequestValidationError


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

# 예외 핸들러 - HTTP 예외가 발생했을 때 UTF-8 인코딩 헤더 추가
@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    return JSONResponse(
        status_code=exc.status_code, 
        content={"detail": exc.detail}, 
        headers={"Content-Type": "application/json; charset=utf-8"}
    )

# 유효성 검증 예외 핸들러
@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    return JSONResponse(
        status_code=422,
        content={"detail": str(exc)},
        headers={"Content-Type": "application/json; charset=utf-8"}
    )

# 여행 계획 데이터 모델
class TravelPlanData(BaseModel):
    ageGroup: Optional[str] = None
    gender: Optional[str] = None
    travelStartDate: Optional[str] = None
    travelEndDate: Optional[str] = None
    departureTime: Optional[str] = None
    arrivalTime: Optional[str] = None
    numberOfTravelers: Optional[int] = None
    accommodationLocation: Optional[str] = None

    class Config:
        json_schema_extra = {
            "example": {
                "ageGroup": "20대",
                "gender": "male",
                "travelStartDate": "2024-07-01T00:00:00.000Z",
                "travelEndDate": "2024-07-05T00:00:00.000Z",
                "departureTime": "09:00",
                "arrivalTime": "18:00",
                "numberOfTravelers": 2,
                "accommodationLocation": "오사카 중앙역 근처"
            }
        }

# 여행 계획 저장소 (임시, 실제로는 DB 연결 필요)
travel_plans = []


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
    try:
        # 데이터 검증 로직은 필요에 따라 추가
        travel_plan = plan_data.dict()
        
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
            'travelStartDate': 
            '2025-04-08T00:00:00.000', 
            'travelEndDate': '2025-04-10T00:00:00.000', 
            'departureTime': '22:31', 
            'arrivalTime': '16:31', 
            'numberOfTravelers': 2, 
            'accommodationLocation': '', 
            'created_at': '2025-04-02T22:31:29+0900', 
            'days': '2박 3일', 
            'start_date': '2025년 04월 08일', 
            'end_date': '2025년 04월 10일'
        }
        """
        travel_plans.append(travel_plan)
        
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


@app.get("/api/travel-plans/")
async def get_travel_plans():
    """
    저장된 모든 여행 계획을 조회합니다.
    """
    return JSONResponse(
        content={
            "status": "success",
            "count": len(travel_plans),
            "data": travel_plans
        },
        headers={"Content-Type": "application/json; charset=utf-8"}
    )


@app.get("/api/travel-plans/{plan_id}")
async def get_travel_plan(plan_id: int):
    """
    특정 여행 계획을 조회합니다.
    
    plan_id: 조회할 여행 계획의 인덱스
    """
    if plan_id < 0 or plan_id >= len(travel_plans):
        raise HTTPException(status_code=404, detail="해당 여행 계획을 찾을 수 없습니다.")
    
    return JSONResponse(
        content={
            "status": "success",
            "current_time": datetime.now(KST).strftime("%Y년 %m월 %d일 %H:%M:%S"),
            "data": travel_plans[plan_id]
        },
        headers={"Content-Type": "application/json; charset=utf-8"}
    )

# 서버 실행 테스트용
if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=1234) 