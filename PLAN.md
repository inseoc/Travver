# Travver - AI 여행 플래너 앱

## 프로젝트 개요

Travver는 AI 기반의 스마트 여행 계획 앱입니다. 사용자의 선호도와 예산에 맞춘 맞춤형 여행 일정을 생성하고, 실시간 AI 컨설팅을 제공하며, 여행 후에는 AI로 특별한 추억을 만들어 드립니다.

---

## 기술 스택

| 영역 | 기술 |
|------|------|
| Frontend | Flutter (Dart) |
| Backend | Python (FastAPI) |
| AI - 일정/상담 | OpenAI GPT-5.2 (Agent 기반) |
| AI - 이미지 | Google Gemini Nano Banana Pro |
| AI - 영상 | Google Gemini Veo 3.1 |
| Database | TBD (SQLite / Supabase / Firebase) |

---

## AI Agent 아키텍처

### Agent 적용 여부 판단 기준
| 기준 | 설명 |
|------|------|
| 다중 도구 활용 | 여러 외부 API/데이터를 조합해야 하는 경우 |
| 복합 추론 | 단순 변환이 아닌 맥락 기반 의사결정이 필요한 경우 |
| 동적 워크플로우 | 사용자 입력에 따라 실행 경로가 달라지는 경우 |

### Agent가 필요한 기능 vs 단순 API 호출

| 기능 | 구현 방식 | 이유 |
|------|-----------|------|
| AI 일정 생성 | **Agent** | 장소 검색, 거리 계산, 날씨 조회 등 다중 도구 조합 |
| AI 컨설턴트 | **Agent** | 실시간 정보 조회, 컨텍스트 기반 추천, 복합 추론 |
| 사진 꾸미기 | 단순 API | 이미지 입력 → Gemini → 변환 이미지 출력 |
| 나만의 영상 | 단순 API | 미디어 입력 → Veo → 영상 출력 |

---

### Agent 1: 여행 일정 생성 Agent (Travel Planner Agent)

**모델**: OpenAI GPT-5.2

**역할**: 사용자 입력을 기반으로 최적의 여행 일정을 자동 생성

**입력**:
- 목적지
- 여행 기간 (시작일 ~ 종료일)
- 여행 인원
- 예산 범위
- 여행 스타일 (맛집/관광/휴양/액티비티/쇼핑/사진명소)

**Tools (Function Calling)**:
| Tool | 설명 | 외부 API |
|------|------|----------|
| `search_places` | 장소 검색 (관광지, 맛집, 숙소) | Google Places API |
| `get_place_details` | 장소 상세 정보 (영업시간, 리뷰, 가격대) | Google Places API |
| `calculate_route` | 두 지점 간 거리/이동시간 계산 | Google Maps Directions API |
| `get_weather_forecast` | 여행 기간 날씨 예보 | OpenWeatherMap API |
| `get_exchange_rate` | 현지 통화 환율 조회 | Exchange Rate API |
| `search_accommodation` | 숙소 검색 및 가격 비교 | (TBD) Booking API |

**워크플로우**:
```
[사용자 입력]
     ↓
[1. 목적지 분석]
  - 도시 정보 파악
  - 여행 적합 시즌 확인
     ↓
[2. 장소 수집] ← search_places, get_place_details
  - 여행 스타일에 맞는 장소 수집
  - 영업시간, 리뷰 점수 필터링
     ↓
[3. 날씨/환율 조회] ← get_weather_forecast, get_exchange_rate
  - 여행 기간 날씨 확인
  - 예산 환산
     ↓
[4. 일정 최적화] ← calculate_route
  - 동선 최적화 (거리/시간 기반)
  - 하루 일정 시간 배분
  - 예산 배분
     ↓
[5. 일정 생성]
  - Day별 타임라인 구성
  - 각 장소별 예상 비용 산출
     ↓
[최종 일정 JSON 출력]
```

**출력 형식**:
```json
{
  "destination": "오사카",
  "period": { "start": "2026-03-01", "end": "2026-03-04" },
  "total_budget": { "estimated": 850000, "currency": "KRW" },
  "weather_summary": "맑음, 평균 15°C",
  "daily_plans": [
    {
      "day": 1,
      "date": "2026-03-01",
      "theme": "도톤보리 & 난바 탐방",
      "schedules": [
        {
          "time": "10:00",
          "place": "구로몬 시장",
          "category": "맛집",
          "duration_min": 90,
          "estimated_cost": 15000,
          "description": "오사카의 부엌, 신선한 해산물 아침 식사",
          "location": { "lat": 34.6687, "lng": 135.5065 }
        }
      ]
    }
  ]
}
```

---

### Agent 2: AI 컨설턴트 Agent (Travel Consultant Agent)

**모델**: OpenAI GPT-5.2

**역할**: 여행 관련 실시간 질의응답 및 맞춤 추천

**컨텍스트**:
- 현재 진행 중인 여행 일정 (있는 경우)
- 대화 히스토리
- 사용자 선호도

**Tools (Function Calling)**:
| Tool | 설명 | 외부 API |
|------|------|----------|
| `search_places` | 장소 검색 | Google Places API |
| `get_weather` | 현재/예보 날씨 조회 | OpenWeatherMap API |
| `get_exchange_rate` | 환율 조회 | Exchange Rate API |
| `search_transportation` | 교통편 검색 | Google Maps / 현지 교통 API |
| `get_current_trip` | 현재 여행 일정 조회 | 내부 DB |
| `web_search` | 실시간 정보 검색 | (TBD) Search API |
| `translate_text` | 현지어 번역 | Google Translate API |

**대화 예시**:
```
사용자: "오늘 저녁 근처 라멘 맛집 추천해줘"
     ↓
Agent 추론:
  1. get_current_trip → 현재 위치: 도톤보리
  2. search_places("라멘", 도톤보리 반경 1km)
  3. 리뷰 점수, 대기 시간 분석
     ↓
응답: "현재 위치 기준 추천 라멘집 3곳입니다:
      1. 이치란 도톤보리점 (도보 3분, 평점 4.5)
      2. 킨류라멘 (도보 5분, 평점 4.3, 24시간)
      ..."
```

**워크플로우**:
```
[사용자 질문]
     ↓
[의도 분석]
  - 장소 추천 / 날씨 / 교통 / 번역 / 일정 수정 / 일반 질문
     ↓
[필요 도구 선택 & 실행]
  - 병렬 실행 가능한 도구는 동시 호출
     ↓
[컨텍스트 결합]
  - 현재 일정 + 도구 결과 + 사용자 선호
     ↓
[자연스러운 응답 생성]
  - 스트리밍 출력
```

---

## UI/UX 디자인 가이드라인

### 디자인 컨셉: "Calm & Refined"
> 세련되고 절제된 디자인으로, 화려하지 않으면서도 눈에 들어오는 구성

### 컬러 팔레트
| 용도 | 색상 | 설명 |
|------|------|------|
| Primary | `#2C3E50` | 깊이 있는 네이비 (신뢰감) |
| Accent | `#E67E22` | 따뜻한 오렌지 (여행의 설렘) |
| Background | `#FAFAFA` | 부드러운 오프화이트 |
| Surface | `#FFFFFF` | 카드/컨테이너 배경 |
| Text Primary | `#1A1A1A` | 본문 텍스트 |
| Text Secondary | `#6B7280` | 보조 텍스트 |

### 타이포그래피
- **헤드라인**: Pretendard Bold, 24-32px
- **서브헤드**: Pretendard SemiBold, 18-20px
- **본문**: Pretendard Regular, 14-16px
- **캡션**: Pretendard Light, 12px

### 디자인 원칙
1. **여백의 미**: 충분한 여백으로 시각적 여유 확보
2. **미니멀 아이콘**: 선형(outline) 아이콘 사용, 2px 굵기 통일
3. **부드러운 곡선**: 카드 radius 16px, 버튼 radius 12px
4. **미묘한 그림자**: `0 2px 8px rgba(0,0,0,0.06)` - 은은한 깊이감
5. **애니메이션**: 300ms ease-out 전환, 과하지 않은 자연스러운 움직임

### 컴포넌트 스타일
- **카드**: 흰색 배경 + 미묘한 그림자 + 16px 패딩
- **버튼 (Primary)**: Accent 컬러 배경, 흰색 텍스트, 터치 시 살짝 어두워짐
- **버튼 (Secondary)**: 투명 배경 + Primary 컬러 테두리
- **입력 필드**: 회색 테두리, 포커스 시 Primary 컬러로 전환
- **탭/네비게이션**: 선택된 항목만 Accent 컬러 강조

---

## 화면 설계

### 1. 스플래시 화면 (Splash Screen)
- **목적**: 앱 로딩 및 브랜드 노출
- **구성 요소**:
  - 중앙: 앱 로고 (심플한 여행 아이콘 + 타이포)
  - 하단: 미니멀한 로딩 인디케이터 (얇은 프로그레스 바)
- **동작**: 2초 후 자동으로 온보딩/홈 화면으로 전환
- **배경**: 그라데이션 (#FAFAFA → #F0F4F8)

---

### 2. 온보딩 화면 (Onboarding Screen)
- **목적**: 앱 사용법 안내 (최초 실행 시)
- **구성 요소**:
  - 3개의 슬라이드 페이지 (풀스크린 일러스트 + 텍스트)
  - 하단: 도트 인디케이터 + "시작하기" 버튼
- **내용**:
  1. **AI 여행 플래너** - "당신만을 위한 맞춤 여행을 설계해요"
  2. **실시간 AI 상담** - "궁금한 건 언제든 물어보세요"
  3. **추억을 작품으로** - "여행의 순간을 특별하게 간직하세요"
- **스타일**: 부드러운 일러스트, 넉넉한 여백, 중앙 정렬 텍스트

---

### 3. 홈 화면 (Home Screen)
- **목적**: 메인 대시보드
- **구성 요소**:
  - **상단**: "안녕하세요, [이름]님" + 현재 날짜 (작은 텍스트)
  - **중앙**: 빠른 액션 카드 (2x2 그리드)
    - [새 여행 계획] - Primary 아이콘
    - [AI 컨설턴트] - 채팅 아이콘
    - [내 여행] - 리스트 아이콘
    - [추억 남기기] - 갤러리 아이콘
  - **하단**: "최근 여행" 섹션 - 가로 스크롤 카드 목록
- **스타일**: 카드에 미묘한 그림자, 아이콘은 선형 스타일

---

### 4. 새 여행 계획 입력 화면 (New Plan Input Screen)
- **목적**: 여행 정보 수집 → **Travel Planner Agent** 호출
- **입력 항목** (단계별 입력 방식):
  - **Step 1**: 목적지 (검색 자동완성)
  - **Step 2**: 여행 기간 (캘린더 피커)
  - **Step 3**: 여행 인원 (숫자 스테퍼)
  - **Step 4**: 예산 범위 (슬라이더)
  - **Step 5**: 여행 스타일 (칩 다중 선택)
    - 맛집 탐방 / 관광 명소 / 휴양 / 액티비티 / 쇼핑 / 사진 명소
- **하단 버튼**: [AI 일정 생성하기] - Full-width Accent 버튼
- **스타일**: 진행 상태 표시 (상단 프로그레스 바), 각 단계는 부드러운 슬라이드 전환
- **Agent 연동**: 버튼 클릭 시 Travel Planner Agent 실행

---

### 5. 여행 계획 결과 화면 (Travel Plan Result Screen)
- **목적**: **Travel Planner Agent**가 생성한 일정 표시
- **구성 요소**:
  - **상단**: 목적지명 + 기간 요약 + 날씨 아이콘
  - **탭 네비게이션**: Day 1 | Day 2 | Day 3 ...
  - **타임라인 뷰**: 시간순 일정 카드
    - 시간 (왼쪽 라인)
    - 장소명 + 카테고리 태그
    - 간단한 설명 (1-2줄)
    - 예상 비용 (작은 텍스트)
  - **하단 플로팅 버튼**:
    - [저장하기] / [수정 요청] (작은 텍스트 버튼)
- **스타일**: 타임라인은 세로선 + 도트로 연결, 카드는 흰색 배경
- **수정 요청**: "수정 요청" 클릭 시 Agent 재호출 (추가 요구사항 입력)

---

### 6. AI 컨설턴트 화면 (AI Consultant Screen)
- **목적**: **Travel Consultant Agent** 기반 실시간 채팅 상담
- **구성 요소**:
  - **상단**: "AI 컨설턴트" 타이틀 + 뒤로가기
  - **채팅 영역**:
    - AI 메시지: 왼쪽 정렬, 밝은 회색 배경
    - 사용자 메시지: 오른쪽 정렬, Accent 컬러 배경
    - Tool 실행 표시: "날씨 정보를 확인하고 있어요..." (로딩 인디케이터)
  - **빠른 질문 칩** (채팅 하단, 가로 스크롤):
    - "추천 맛집" / "날씨 정보" / "교통편" / "숙소 추천" / "이 말 번역해줘"
  - **입력창**: 둥근 텍스트필드 + 전송 버튼
- **동작**: 실시간 스트리밍 응답 (타이핑 애니메이션)
- **Agent 연동**: 모든 메시지는 Travel Consultant Agent가 처리

---

### 7. 내 여행 목록 화면 (My Trips Screen)
- **목적**: 저장된 여행 계획 관리
- **구성 요소**:
  - **상단**: "내 여행" 타이틀
  - **필터 탭**: 전체 | 예정 | 진행중 | 완료
  - **여행 카드 목록** (세로 스크롤):
    - 대표 이미지 (상단, 라운드 처리)
    - 목적지명 + 기간
    - 상태 뱃지 (색상으로 구분)
  - **빈 상태**: 일러스트 + "새 여행을 계획해보세요" 버튼
- **인터랙션**: 카드 탭 → 상세 화면, 왼쪽 스와이프 → 삭제

---

### 8. 추억 남기기 화면 (Memories Screen)
- **목적**: 여행 사진/영상을 AI로 특별한 추억으로 변환
- **진입 조건**: 완료된 여행이 있을 때 활성화
- **구성 요소**:
  - **상단**: "추억 남기기" 타이틀 + 여행 선택 드롭다운
  - **메인 영역**: 2개의 큰 카드 (세로 배치)
    - [사진 꾸미기] - 카메라/이미지 아이콘
    - [나만의 영상] - 비디오 아이콘
  - **하단**: 이전에 만든 추억 갤러리 (썸네일 그리드)

---

### 8-1. 사진 꾸미기 화면 (Photo Decorator Screen)
- **목적**: AI로 여행 사진을 예술적으로 꾸미기
- **AI 엔진**: Google Gemini Nano Banana Pro (단순 API 호출)
- **구성 요소**:
  - **상단**: "사진 꾸미기" 타이틀
  - **갤러리 접근 영역**:
    - 자동 필터링: 선택한 여행 기간 내 촬영된 사진만 표시
    - 그리드 뷰로 사진 목록 표시
    - 다중 선택 가능 (최대 10장)
  - **스타일 선택** (가로 스크롤 칩):
    - 수채화 / 유화 / 스케치 / 빈티지 / 영화 포스터 / 팝아트
  - **미리보기 영역**: 선택한 사진 + 적용될 스타일 프리뷰
  - **하단 버튼**: [AI로 꾸미기 시작]
- **결과 화면**:
  - 변환된 이미지 표시
  - [저장] / [공유] / [다시 만들기] 버튼
- **갤러리 필터 로직**:
  ```
  여행 시작일 <= 사진 촬영일 <= 여행 종료일
  (MediaStore API 활용 - Android/갤럭시)
  ```

---

### 8-2. 나만의 영상 화면 (Video Creator Screen)
- **목적**: 여행 사진/영상을 AI로 시네마틱 영상 생성
- **AI 엔진**: Google Gemini Veo 3.1 (단순 API 호출)
- **구성 요소**:
  - **상단**: "나만의 영상" 타이틀
  - **갤러리 접근 영역**:
    - 자동 필터링: 선택한 여행 기간 내 촬영된 미디어만 표시
    - 탭 전환: 사진 | 영상 | 전체
    - 다중 선택 (사진 최대 20장, 영상 최대 5개)
  - **영상 스타일 선택**:
    - 시네마틱 여행 / 감성 브이로그 / 다이나믹 하이라이트 / 추억 앨범
  - **배경음악 선택** (옵션):
    - 잔잔한 / 신나는 / 감성적인 / 없음
  - **영상 길이**: 15초 / 30초 / 60초
  - **하단 버튼**: [AI 영상 만들기]
- **생성 중 화면**:
  - 프로그레스 인디케이터 + "특별한 영상을 만들고 있어요"
  - 예상 소요 시간 표시
- **결과 화면**:
  - 풀스크린 영상 플레이어
  - [저장] / [공유] / [다시 만들기] 버튼
- **갤러리 필터 로직**:
  ```
  여행 시작일 <= 미디어 생성일 <= 여행 종료일
  지원 포맷: JPG, PNG, HEIC, MP4, MOV
  (MediaStore API 활용 - Android/갤럭시)
  ```

---

## 핵심 기능 목록

### MVP (Phase 1)
| 기능 | 설명 | 구현 방식 | 우선순위 |
|------|------|-----------|----------|
| 스플래시/온보딩 | 앱 초기 진입 화면 | UI | P0 |
| 여행 계획 입력 | 목적지, 기간, 예산 등 입력 | UI | P0 |
| AI 일정 생성 | GPT-5.2 기반 여행 일정 자동 생성 | **Agent** | P0 |
| 일정 저장/조회 | 생성된 일정 로컬 저장 | CRUD | P0 |
| AI 채팅 상담 | 실시간 여행 관련 질의응답 | **Agent** | P1 |

### Phase 2
| 기능 | 설명 | 구현 방식 | 우선순위 |
|------|------|-----------|----------|
| 사진 꾸미기 | Gemini Nano Banana Pro로 사진 변환 | API 호출 | P2 |
| 나만의 영상 | Veo 3.1로 AI 영상 생성 | API 호출 | P2 |
| 갤러리 연동 | 여행 기간 기반 미디어 자동 필터링 | Native API | P2 |
| 지도 연동 | 장소 위치 지도에 표시 | Google Maps | P2 |

### Phase 3
| 기능 | 설명 | 구현 방식 | 우선순위 |
|------|------|-----------|----------|
| 사용자 인증 | 로그인/회원가입 | Auth | P3 |
| 클라우드 동기화 | 여러 기기 간 데이터 동기화 | Cloud DB | P3 |
| 일정/추억 공유 | SNS 공유 기능 | Share API | P3 |
| 푸시 알림 | 여행 일정 리마인더 | FCM | P3 |

---

## 폴더 구조 (예정)

```
travver/
├── lib/                              # Flutter 프론트엔드
│   ├── main.dart
│   ├── app/
│   │   ├── routes.dart
│   │   └── theme.dart                # 디자인 시스템 정의
│   ├── screens/
│   │   ├── splash/
│   │   ├── onboarding/
│   │   ├── home/
│   │   ├── plan_input/
│   │   ├── plan_result/
│   │   ├── ai_consultant/
│   │   ├── my_trips/
│   │   └── memories/
│   │       ├── memories_screen.dart
│   │       ├── photo_decorator_screen.dart
│   │       └── video_creator_screen.dart
│   ├── widgets/                      # 재사용 위젯
│   ├── models/                       # 데이터 모델
│   ├── services/
│   │   ├── api_service.dart          # Backend API 통신
│   │   └── gallery_service.dart      # 갤러리 접근
│   └── providers/                    # 상태 관리
├── backend/                          # Python 백엔드
│   ├── main.py                       # FastAPI 엔트리포인트
│   ├── routes/
│   │   ├── travel.py                 # 여행 CRUD
│   │   ├── agent.py                  # Agent 엔드포인트
│   │   └── memories.py               # 추억 생성 API
│   ├── agents/                       # AI Agent 정의
│   │   ├── travel_planner_agent.py   # 여행 일정 생성 Agent
│   │   └── travel_consultant_agent.py # AI 컨설턴트 Agent
│   ├── tools/                        # Agent Tools
│   │   ├── places_tool.py            # Google Places 연동
│   │   ├── maps_tool.py              # Google Maps 연동
│   │   ├── weather_tool.py           # 날씨 API 연동
│   │   ├── exchange_tool.py          # 환율 API 연동
│   │   └── translate_tool.py         # 번역 API 연동
│   ├── services/
│   │   ├── openai_service.py         # GPT-5.2 연동
│   │   ├── gemini_service.py         # Gemini Nano Banana Pro 연동
│   │   └── veo_service.py            # Veo 3.1 연동
│   └── requirements.txt
├── assets/
│   ├── images/
│   ├── icons/
│   └── fonts/                        # Pretendard 폰트
└── PLAN.md
```

---

## 다음 단계

- [ ] 화면별 상세 와이어프레임 작성 (Figma)
- [ ] Flutter 프로젝트 초기 설정
- [ ] 디자인 시스템 구현 (theme.dart)
- [ ] Backend FastAPI 프로젝트 초기 설정
- [ ] Travel Planner Agent 구현 (GPT-5.2 + Tools)
- [ ] Travel Consultant Agent 구현 (GPT-5.2 + Tools)
- [ ] Gemini Nano Banana Pro API 연동 테스트
- [ ] Gemini Veo 3.1 API 연동 테스트
- [ ] 데이터베이스 스키마 설계

---

## 변경 이력

| 날짜 | 내용 |
|------|------|
| 2026-01-15 | 초기 계획 문서 생성 |
| 2026-01-15 | 예산관리 화면 제거, 추억 남기기 화면 추가 (사진 꾸미기/나만의 영상) |
| 2026-01-15 | UI/UX 디자인 가이드라인 추가 |
| 2026-01-15 | Gemini API (Nano/Pro, Veo 3.1) 기술 스택 추가 |
| 2026-01-15 | AI 모델 변경: GPT-5.2, Gemini Nano Banana Pro |
| 2026-01-15 | AI Agent 아키텍처 추가 (Travel Planner Agent, Travel Consultant Agent) |
