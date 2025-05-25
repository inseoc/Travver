import os

from dotenv import load_dotenv
load_dotenv("C:/Users/82108/Desktop/dev_study/travver/backend/.env")

import googlemaps
from fastmcp import FastMCP

fastmcp = FastMCP()
mcp_server = FastMCP(name="Demo", 
                     instructions="You are a helpful assistant.")

gmaps = googlemaps.Client(os.getenv("GOOGLE_MAP_GEO"))

@mcp_server.tool()
async def find_location(location: str) -> list[dict]:
    try:
        return gmaps.geocode(location, language='ko')
    except Exception as e:
        return f"Error: {e}"


if __name__ == "__main__":
    print("hello")