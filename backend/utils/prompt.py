class AgentPromptTemplate:

    generate_base_plan_prompt = """
    새 여행 플랜 생성하기 위해 두 화면에서 입력받은 값을
    토대로 Agent 에게 전달하기 위한 프롬프트 입니다.

    아래의 **여행객 정보** 와 **추가 정보** 를 토대로 해당 여행객에게 적합한 여행 플랜을 작성해주세요.

    **여행객 정보**
    1. 연령대: {ageGroup}
    2. 성별: {gender}
    3. 여행 시작일: {travelStartDate}
    4. 여행 종료일: {travelEndDate}
    5. 한국 출국 시간: {kor_departureTime}
    6. 일본 출국 시간: {jpn_departureTime}
    7. 여행 인원: {numberOfTravelers}
    8. 숙박 장소: {accommodationLocation}
    """

    additional_info_prompt = """
    **추가 정보**
    {additionalInfo}
    """

    advanced_plan_prompt = """
    여행 계획에 대한 사용자의 추가 입력 정보를 토대로 여행 계획을 수정 및 고도화 해주세요.

    사용자의 추가 정보: {preference}
    """
