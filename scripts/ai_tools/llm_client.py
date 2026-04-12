import os
import sys
from google import genai
from google.genai import types

def get_client():
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        print("ERROR: GEMINI_API_KEY environment variable not set.", file=sys.stderr)
        sys.exit(1)
    return genai.Client(api_key=api_key)

def generate_content(prompt: str, model: str = "gemini-2.5-pro", temperature: float = 0.2) -> str:
    client = get_client()
    try:
        response = client.models.generate_content(
            model=model,
            contents=prompt,
            config=types.GenerateContentConfig(
                temperature=temperature,
            ),
        )
        return response.text
    except Exception as e:
        print(f"ERROR: Failed to generate content: {e}", file=sys.stderr)
        sys.exit(1)
