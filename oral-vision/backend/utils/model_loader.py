import pickle
import torch
import joblib
import torch.nn as nn
from ultralytics import YOLO
from utils.oral_model import OralVisionModel

MODEL_DIR = "models/"

def load_yolo():
    return YOLO(MODEL_DIR + "best.pt")

def load_feature_extractor():
    ckpt = torch.load(MODEL_DIR + "your_improved_feature_extractor.pth",
                      map_location="cpu", weights_only=False)
    model = OralVisionModel(
        num_classes=ckpt["num_classes"],
        num_heads=ckpt["num_heads"],
        attn_dim=ckpt["attn_dim"]
    )
    model.load_state_dict(ckpt["model_state_dict"])
    model.eval()
    return model

def load_oral_xgboost():
    with open(MODEL_DIR + "your_improved_xgboost.pkl", "rb") as f:
        return pickle.load(f)

def load_scaler():
    try:
        return joblib.load(MODEL_DIR + "your_improved_scaler.pkl")
    except:
        with open(MODEL_DIR + "your_improved_scaler.pkl", "rb") as f:
            return pickle.load(f)

def load_symptom_model():
    with open(MODEL_DIR + "OralVision_xgboost.pkl", "rb") as f:
        return pickle.load(f)

def load_gender_encoder():
    with open(MODEL_DIR + "gender_encoder.pkl", "rb") as f:
        return pickle.load(f)

def load_label_encoder():
    with open(MODEL_DIR + "label_encoder.pkl", "rb") as f:
        return pickle.load(f)
