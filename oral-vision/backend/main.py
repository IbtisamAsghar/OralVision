from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers import predict, symptom, chatbot
import uvicorn

app = FastAPI(title="OralVision API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(predict.router, prefix="/predict", tags=["Predict"])
app.include_router(symptom.router, prefix="/symptom", tags=["Symptom"])
app.include_router(chatbot.router, prefix="/chatbot", tags=["Chatbot"])

@app.get("/")
def home():
    return {"message": "OralVision API is running!"}

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)