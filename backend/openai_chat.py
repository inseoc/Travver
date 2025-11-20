import os

from pydantic import Field, BaseModel
from dotenv import load_dotenv
load_dotenv()

from openai import OpenAI

client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))


class MessageOutput(BaseModel):
    name: str
    date: str


def openai_chat(input_text: str) -> str:
    response = client.responses.create(
        model=os.getenv("OPENAI_MODEL_NAME"),
        input=input_text
    )

    return response.output_text


def openai_chat_with_format(input_text: str, input_format: BaseModel) -> str:
    response = client.responses.parse(
        model=os.getenv("OPENAI_MODEL_NAME"),
        instructions="간단한 이벤트 정보를 추출하세요.",
        input=input_text,
        text_format=MessageOutput,
    )

    return response.output_text
    
if __name__ == "__main__":
    # print(openai_chat("안녕하세요. 당신은 누구인가요?"))
    print(openai_chat_with_format("10월 26일에 홍길동과 김철수 참석 예정", MessageOutput))