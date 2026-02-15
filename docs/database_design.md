# Travver SQLite Database Design

## Overview

현재 Travver 앱은 `SharedPreferences`(프론트엔드)와 `In-Memory Dict`(백엔드)로 데이터를 관리하고 있다.
이를 SQLite 기반의 구조화된 로컬 DB로 전환하기 위한 테이블 설계서이다.

- **ORM**: sqflite (pubspec.yaml에 이미 포함, 미사용 상태)
- **대상 플랫폼**: Android, iOS

---

## ERD (Entity Relationship)

```
app_config (1)

trips (1) ──< daily_plans (N) ──< schedules (N)
  │
  ├──< decorated_photos (N)
  │
  └──< chat_messages (N)
```

---

## 1. app_config

앱 설정 및 사용자 기본 정보를 Key-Value 형태로 저장한다.

> 기존: `SharedPreferences` (isFirstLaunch, userName)

| Column | Type    | Constraint  | Description          |
|--------|---------|-------------|----------------------|
| key    | TEXT    | PRIMARY KEY | 설정 키               |
| value  | TEXT    | NOT NULL    | 설정 값               |

**사용 예시:**

| key            | value    |
|----------------|----------|
| is_first_launch | true    |
| user_name      | 여행자   |

```sql
CREATE TABLE app_config (
    key   TEXT PRIMARY KEY,
    value TEXT NOT NULL
);
```

---

## 2. trips

여행 계획의 최상위 엔티티. AI가 생성한 여행 일정의 메타 정보를 저장한다.

> 기존: `SharedPreferences` StringList (JSON 직렬화)
> 모델: `Trip`, `TripPeriod`, `Budget`

| Column                 | Type    | Constraint                    | Description                    |
|------------------------|---------|-------------------------------|--------------------------------|
| id                     | TEXT    | PRIMARY KEY                   | trip_{uuid}                    |
| destination            | TEXT    | NOT NULL                      | 여행지 (e.g. "오사카")           |
| period_start           | TEXT    | NOT NULL                      | 여행 시작일 (YYYY-MM-DD)        |
| period_end             | TEXT    | NOT NULL                      | 여행 종료일 (YYYY-MM-DD)        |
| travelers              | INTEGER | NOT NULL DEFAULT 1            | 여행 인원 (1~50)                |
| budget_estimated       | INTEGER | NOT NULL DEFAULT 0            | 예상 예산 (KRW)                 |
| budget_currency        | TEXT    | NOT NULL DEFAULT 'KRW'        | 통화 코드                       |
| styles                 | TEXT    | NOT NULL DEFAULT '[]'         | 여행 스타일 JSON 배열            |
| custom_preference      | TEXT    |                               | 사용자 커스텀 선호도              |
| accommodation_location | TEXT    |                               | 숙소 위치                       |
| status                 | TEXT    | NOT NULL DEFAULT 'upcoming'   | upcoming / ongoing / completed |
| image_url              | TEXT    |                               | 여행 대표 이미지 URL             |
| created_at             | TEXT    | NOT NULL                      | 생성 시각 (ISO 8601)            |
| updated_at             | TEXT    | NOT NULL                      | 수정 시각 (ISO 8601)            |

**styles 컬럼 예시:** `["food","sightseeing","photo"]`

```sql
CREATE TABLE trips (
    id                     TEXT    PRIMARY KEY,
    destination            TEXT    NOT NULL,
    period_start           TEXT    NOT NULL,
    period_end             TEXT    NOT NULL,
    travelers              INTEGER NOT NULL DEFAULT 1,
    budget_estimated       INTEGER NOT NULL DEFAULT 0,
    budget_currency        TEXT    NOT NULL DEFAULT 'KRW',
    styles                 TEXT    NOT NULL DEFAULT '[]',
    custom_preference      TEXT,
    accommodation_location TEXT,
    status                 TEXT    NOT NULL DEFAULT 'upcoming',
    image_url              TEXT,
    created_at             TEXT    NOT NULL,
    updated_at             TEXT    NOT NULL
);

CREATE INDEX idx_trips_status     ON trips(status);
CREATE INDEX idx_trips_created_at ON trips(created_at);
```

---

## 3. daily_plans

여행의 일별 계획. 하나의 Trip에 N개의 DailyPlan이 포함된다.

> 모델: `DailyPlan`

| Column  | Type    | Constraint                                | Description              |
|---------|---------|-------------------------------------------|--------------------------|
| id      | INTEGER | PRIMARY KEY AUTOINCREMENT                 | 내부 PK                   |
| trip_id | TEXT    | NOT NULL REFERENCES trips(id) ON DELETE CASCADE | 소속 여행 FK          |
| day     | INTEGER | NOT NULL                                  | 일차 (1부터 시작)          |
| date    | TEXT    | NOT NULL                                  | 해당 날짜 (YYYY-MM-DD)    |
| theme   | TEXT    | NOT NULL                                  | 일별 테마 (e.g. "도톤보리 탐방") |

```sql
CREATE TABLE daily_plans (
    id      INTEGER PRIMARY KEY AUTOINCREMENT,
    trip_id TEXT    NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    day     INTEGER NOT NULL,
    date    TEXT    NOT NULL,
    theme   TEXT    NOT NULL,
    UNIQUE(trip_id, day)
);

CREATE INDEX idx_daily_plans_trip_id ON daily_plans(trip_id);
```

---

## 4. schedules

일별 계획 내 개별 일정 항목. 장소, 시간, 비용, 좌표 등을 포함한다.

> 모델: `Schedule`, `Location`, `PlaceCategory`

| Column        | Type    | Constraint                                          | Description                  |
|---------------|---------|-----------------------------------------------------|------------------------------|
| id            | INTEGER | PRIMARY KEY AUTOINCREMENT                           | 내부 PK                       |
| daily_plan_id | INTEGER | NOT NULL REFERENCES daily_plans(id) ON DELETE CASCADE | 소속 일별 계획 FK             |
| order_index   | INTEGER | NOT NULL                                            | 순서 (1부터 시작)              |
| time          | TEXT    | NOT NULL                                            | 시작 시각 (HH:MM)             |
| place         | TEXT    | NOT NULL                                            | 장소명                        |
| category      | TEXT    | NOT NULL                                            | food / sightseeing / accommodation / activity / shopping / transport / rest / photo |
| duration_min  | INTEGER | NOT NULL                                            | 소요 시간 (분)                 |
| estimated_cost| INTEGER | NOT NULL DEFAULT 0                                  | 예상 비용 (KRW)               |
| description   | TEXT    | NOT NULL DEFAULT ''                                 | 장소 설명                      |
| latitude      | REAL    | NOT NULL                                            | 위도                          |
| longitude     | REAL    | NOT NULL                                            | 경도                          |
| image_url     | TEXT    |                                                     | 장소 이미지 URL                |
| rating        | REAL    |                                                     | 평점 (0.0~5.0)                |
| place_id      | TEXT    |                                                     | Google Places ID              |

```sql
CREATE TABLE schedules (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    daily_plan_id  INTEGER NOT NULL REFERENCES daily_plans(id) ON DELETE CASCADE,
    order_index    INTEGER NOT NULL,
    time           TEXT    NOT NULL,
    place          TEXT    NOT NULL,
    category       TEXT    NOT NULL,
    duration_min   INTEGER NOT NULL,
    estimated_cost INTEGER NOT NULL DEFAULT 0,
    description    TEXT    NOT NULL DEFAULT '',
    latitude       REAL    NOT NULL,
    longitude      REAL    NOT NULL,
    image_url      TEXT,
    rating         REAL,
    place_id       TEXT,
    UNIQUE(daily_plan_id, order_index)
);

CREATE INDEX idx_schedules_daily_plan_id ON schedules(daily_plan_id);
CREATE INDEX idx_schedules_category      ON schedules(category);
```

---

## 5. decorated_photos

AI로 꾸며진 사진. Trip에 종속된다.

> 기존: `SharedPreferences` StringList (JSON 직렬화)
> 모델: `DecoratedPhoto`

| Column              | Type | Constraint                                      | Description                   |
|---------------------|------|-------------------------------------------------|-------------------------------|
| id                  | TEXT | PRIMARY KEY                                     | photo_{uuid} 또는 서버 발급 ID  |
| trip_id             | TEXT | NOT NULL REFERENCES trips(id) ON DELETE CASCADE | 소속 여행 FK                    |
| original_filename   | TEXT | NOT NULL                                        | 원본 파일명                      |
| style               | TEXT | NOT NULL                                        | watercolor / oil_painting / sketch / vintage / movie_poster / pop_art |
| result_image_base64 | TEXT | NOT NULL                                        | 결과 이미지 Base64               |
| result_mime_type    | TEXT | NOT NULL DEFAULT 'image/jpeg'                   | MIME 타입                       |
| created_at          | TEXT | NOT NULL                                        | 생성 시각 (ISO 8601)            |

```sql
CREATE TABLE decorated_photos (
    id                  TEXT PRIMARY KEY,
    trip_id             TEXT NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
    original_filename   TEXT NOT NULL,
    style               TEXT NOT NULL,
    result_image_base64 TEXT NOT NULL,
    result_mime_type    TEXT NOT NULL DEFAULT 'image/jpeg',
    created_at          TEXT NOT NULL
);

CREATE INDEX idx_decorated_photos_trip_id    ON decorated_photos(trip_id);
CREATE INDEX idx_decorated_photos_created_at ON decorated_photos(created_at);
```

---

## 6. chat_messages

AI 여행 컨설턴트와의 대화 기록. 선택적으로 Trip에 연결 가능하다.

> 모델: `ChatMessage`, `MessageRole`, `MessageStatus`

| Column       | Type    | Constraint                | Description                       |
|--------------|---------|---------------------------|-----------------------------------|
| id           | TEXT    | PRIMARY KEY               | 메시지 고유 ID                      |
| trip_id      | TEXT    | REFERENCES trips(id) ON DELETE SET NULL | 연관 여행 (선택)           |
| role         | TEXT    | NOT NULL                  | user / assistant / system          |
| content      | TEXT    | NOT NULL                  | 메시지 내용                         |
| status       | TEXT    | NOT NULL DEFAULT 'sent'   | sending / sent / error             |
| is_tool_call | INTEGER | NOT NULL DEFAULT 0        | 도구 호출 여부 (0/1)                |
| tool_name    | TEXT    |                           | 호출된 도구명 (search_places 등)     |
| timestamp    | TEXT    | NOT NULL                  | 발송 시각 (ISO 8601)               |

```sql
CREATE TABLE chat_messages (
    id           TEXT    PRIMARY KEY,
    trip_id      TEXT    REFERENCES trips(id) ON DELETE SET NULL,
    role         TEXT    NOT NULL,
    content      TEXT    NOT NULL,
    status       TEXT    NOT NULL DEFAULT 'sent',
    is_tool_call INTEGER NOT NULL DEFAULT 0,
    tool_name    TEXT,
    timestamp    TEXT    NOT NULL
);

CREATE INDEX idx_chat_messages_trip_id   ON chat_messages(trip_id);
CREATE INDEX idx_chat_messages_timestamp ON chat_messages(timestamp);
```

---

## Indexes Summary

| Table            | Index Name                          | Columns       | Purpose                  |
|------------------|-------------------------------------|---------------|--------------------------|
| trips            | idx_trips_status                    | status        | 상태별 여행 필터링          |
| trips            | idx_trips_created_at                | created_at    | 최신순 정렬                |
| daily_plans      | idx_daily_plans_trip_id             | trip_id       | 여행별 일정 조회            |
| schedules        | idx_schedules_daily_plan_id         | daily_plan_id | 일별 계획의 스케줄 조회      |
| schedules        | idx_schedules_category              | category      | 카테고리별 장소 필터링       |
| decorated_photos | idx_decorated_photos_trip_id        | trip_id       | 여행별 사진 조회            |
| decorated_photos | idx_decorated_photos_created_at     | created_at    | 최신순 정렬                |
| chat_messages    | idx_chat_messages_trip_id           | trip_id       | 여행 맥락별 대화 조회        |
| chat_messages    | idx_chat_messages_timestamp         | timestamp     | 시간순 정렬                |

---

## Migration: SharedPreferences -> SQLite

현재 데이터 저장 방식과 SQLite 전환 매핑:

| 현재 저장 방식                          | SQLite 테이블          |
|----------------------------------------|----------------------|
| SharedPreferences `trips` (StringList) | trips + daily_plans + schedules |
| SharedPreferences `decorated_photos` (StringList) | decorated_photos |
| SharedPreferences `isFirstLaunch` (bool) | app_config         |
| SharedPreferences `userName` (String)  | app_config           |
| In-Memory (Provider 내 ChatMessage)     | chat_messages        |

---

## Schema Version Management

```sql
-- 앱 최초 실행 시 DB 생성
-- sqflite의 onCreate / onUpgrade 콜백 활용

-- Version 1: Initial schema
PRAGMA user_version = 1;
PRAGMA foreign_keys = ON;
```
