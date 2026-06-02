import os
from dotenv import load_dotenv
import google.generativeai as genai

# Load env variables from frontend/.env for testing
load_dotenv(dotenv_path='../frontend/oralvision/.env')

api_key = os.getenv("GEMINI_API_KEY")
if not api_key:
    print("No API key found in .env")
    exit(1)

genai.configure(api_key=api_key)

print("Listing available models...")
try:
    for model in genai.list_models():
        if 'generateContent' in model.supported_generation_methods:
            print(model.name)
except Exception as e:
    print(f"Error listing models: {e}")
