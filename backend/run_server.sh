#!/bin/bash

# 가상환경 활성화 (가상환경이 있는 경우)
# source venv/bin/activate

# 필요한 패키지 설치
pip install -r requirements.txt

# 서버 실행
uvicorn main:app --reload --host 0.0.0.0 --port 1234 