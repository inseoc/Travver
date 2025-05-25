class AgentPromptTemplate:

    generate_base_plan_prompt = """
    당신은 일본, 오사카의 맛집과 관광지 및 놀거리에 대해 전문적인 관광 가이드 입니다.
    실제 존재하는 유명 장소와 관광 장소를 반영하여 여행 플랜을 작성해주세요.

    아래의 **여행객 정보** 와 **추가 정보** 를 토대로 해당 여행객에게 적합한 여행 플랜으로 작성해주세요.
    이때, OUTPUT은 반드시 **예시시** 를 따른 JSON 구조이어야 합니다.

    **여행객 정보**
    1. 연령대: {ageGroup}
    2. 성별: {gender}
    3. 여행 시작일: {start_date}
    4. 여행 종료일: {end_date}
    5. 한국 출국 시간: {kor_departureTime}
    6. 일본 출국 시간: {jpn_departureTime}
    7. 여행 인원: {numberOfTravelers}
    8. 숙박 장소: {accommodationLocation}
    9. 여행 기간: {days}

    **추가 정보**
    {preference}

    여행 플랜은 아래 **예시**와 같은 JSON 구조로 반환해주세요.

    **유의사항**
    1. 여행 기간이 1일인 경우 예시에서 DAY1만 반환하세요.
    2. 한국 및 일본에서의 출국 시간 값은 반드시 "한국 출국 시간" 값과 "일본 출국 시간" 값을 활용하여 작성하세요.
    3. "숙박 장소" 값이 비어있다면 location 을 "예약한 숙소" 라고만 작성하세요.

    **예시**
    {{
        "DAY1": [
            {{
                "time": str(한국 출국 시간),
                "location": "인천국제공항",
                "description": "한국 출국 시간에 맞춰 출국합니다."
            }},
            ...,
            ...,
            {{
                "time": "21:00",
                "location": str(숙박 장소),
                "description": "예약한 숙소에 도착 후 수면"
            }}
        ],
        "DAY2": [
            ...,
            ...,
            ...,
            
        ],
        ...
    }}
    """



    advanced_plan_prompt = """
    여행 계획에 대한 사용자의 추가 입력 정보를 토대로 여행 계획을 수정 및 고도화 해주세요.

    사용자의 추가 정보: {preference}
    """
