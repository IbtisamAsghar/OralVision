from fastapi import APIRouter, File, UploadFile
from PIL import Image
import io
import torch
import numpy as np
from utils.model_loader import (
    load_yolo, 
    load_feature_extractor, 
    load_oral_xgboost, 
    load_scaler
)

router = APIRouter()

yolo_model = load_yolo()
feature_extractor = load_feature_extractor()
oral_xgboost = load_oral_xgboost()
scaler = load_scaler()

@router.post("/")
async def predict_disease(file: UploadFile = File(...)):
    contents = await file.read()
    image = Image.open(io.BytesIO(contents)).convert("RGB")
    
    yolo_results = yolo_model(image)
    
    img_tensor = torch.tensor(
        np.array(image.resize((224, 224)))
    ).permute(2, 0, 1).float().unsqueeze(0) / 255.0
    
    with torch.no_grad():
        features = feature_extractor(img_tensor)
        features = features.numpy()
    
    features_scaled = scaler.transform(features)
    prediction = oral_xgboost.predict(features_scaled)
    confidence = oral_xgboost.predict_proba(features_scaled).max()
    
    return {
        "disease": str(prediction[0]),
        "confidence": float(confidence),
        "segments": len(yolo_results[0].boxes)
    }