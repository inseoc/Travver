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
    
    @classmethod
    def create_final_prompt(cls, travel_plan, user_preference):
        """
        여행 계획 데이터와 사용자 선호도 정보를 합쳐서 최종 프롬프트를 생성합니다.
        
        Args:
            travel_plan (dict): '/api/travel-plans/'에서 생성된 여행 계획 데이터
            user_preference (dict): '/api/travel-plans/preferences'에서 생성된 사용자 선호도 데이터
            
        Returns:
            str: 최종 프롬프트 문자열
        """
        # 여행 계획 정보로 기본 프롬프트 생성
        base_prompt = cls.generate_base_plan_prompt.format(
            ageGroup=travel_plan.get('ageGroup', '정보 없음'),
            gender=travel_plan.get('gender', '정보 없음'),
            travelStartDate=travel_plan.get('start_date', travel_plan.get('travelStartDate', '정보 없음')),
            travelEndDate=travel_plan.get('end_date', travel_plan.get('travelEndDate', '정보 없음')),
            kor_departureTime=travel_plan.get('kor_departureTime', '정보 없음'),
            jpn_departureTime=travel_plan.get('jpn_departureTime', '정보 없음'),
            numberOfTravelers=travel_plan.get('numberOfTravelers', '정보 없음'),
            accommodationLocation=travel_plan.get('accommodationLocation', '정보 없음')
        )
        
        # 사용자 선호도 정보가 있으면 추가 정보 프롬프트 추가
        if user_preference and 'userPreference' in user_preference:
            additional_prompt = cls.additional_info_prompt.format(
                additionalInfo=user_preference.get('userPreference', '')
            )
            final_prompt = base_prompt + "\n" + additional_prompt
        else:
            final_prompt = base_prompt
            
        return final_prompt