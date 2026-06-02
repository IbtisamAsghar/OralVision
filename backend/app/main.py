from fastapi import FastAPI
from contextlib import asynccontextmanager
import joblib
import os
import logging
from dotenv import load_dotenv
from fastapi.middleware.cors import CORSMiddleware
from app.routers import symptoms

# Load env variables for local testing
load_dotenv()

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Define paths to ML artifacts
MODELS_DIR = os.path.join(os.path.dirname(__file__), "models")
MODEL_PATH = os.path.join(MODELS_DIR, "best_model.pkl")
SCALER_PATH = os.path.join(MODELS_DIR, "scaler.pkl")
ENCODER_PATH = os.path.join(MODELS_DIR, "label_encoder.pkl")

# Global dictionary to hold models for easy injection
ml_models = {}

@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Lifecycle event to manage ML Models cleanly.
    Loads models into memory when the server starts and clears them on shutdown.
    This prevents OOM (Out of Memory) crashes on Koyeb's 512MB RAM tier.
    """
    logger.info("Server starting up...")
    
    # Lazy Loading: Only load if files exist (prevents crashes if models are missing initially)
    if os.path.exists(MODEL_PATH) and os.path.exists(SCALER_PATH) and os.path.exists(ENCODER_PATH):
        logger.info("Loading ML Artifacts into memory...")
        ml_models["model"] = joblib.load(MODEL_PATH)
        ml_models["scaler"] = joblib.load(SCALER_PATH)
        ml_models["encoder"] = joblib.load(ENCODER_PATH)
        logger.info("Successfully loaded ML models.")
    else:
        logger.warning("ML Artifacts not found! Ensure the training pipeline was executed.")

    yield # The app runs while yielded

    # Clean up memory on shutdown
    logger.info("Server shutting down. Clearing ML models from memory...")
    ml_models.clear()


app = FastAPI(
    title="OralVision AI Backend",
    description="Scalable ML Backend for OralVision Symptoms & Image Prediction",
    version="1.0.0",
    lifespan=lifespan
)

# Allow Flutter frontend to connect
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], # Update for production security
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(symptoms.router)

@app.get("/")
async def root():
    return {
        "message": "Welcome to the OralVision AI Backend API",
        "status": "Online",
        "model_loaded": "model" in ml_models
    }
