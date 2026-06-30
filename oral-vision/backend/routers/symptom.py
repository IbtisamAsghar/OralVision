import os
import joblib
import numpy as np
from fastapi import APIRouter
from pydantic import BaseModel, Field

router = APIRouter()

MODEL_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "models", "symptom")

symptom_model = None
scaler = None
label_encoder = None
_models_loaded = False


def _load_models():
    global symptom_model, scaler, label_encoder, _models_loaded
    if _models_loaded:
        return symptom_model is not None
    _models_loaded = True
    try:
        symptom_model = joblib.load(os.path.join(MODEL_DIR, "best_model.pkl"))
        scaler = joblib.load(os.path.join(MODEL_DIR, "scaler.pkl"))
        label_encoder = joblib.load(
            os.path.join(MODEL_DIR, "symptom_label_encoder.pkl")
        )
        return True
    except (FileNotFoundError, OSError):
        return False


FEATURE_ORDER = [
    "toothache",
    "hot_cold_sensitivity",
    "swollen_gums",
    "bleeding_gums",
    "bad_breath",
    "white_patches",
    "loose_teeth",
    "fever",
    "jaw_swelling",
    "pain_when_chewing",
    "mouth_sores",
]

RECOMMENDATIONS = {
    "Dental Caries (Cavity)": "Avoid sugary foods, brush twice daily with fluoride toothpaste, and schedule a dental filling as soon as possible.",
    "Gingivitis": "Improve oral hygiene, use antiseptic mouthwash, and visit a dentist for professional cleaning.",
    "Periodontitis": "Seek immediate periodontal care. Advanced gum disease can lead to tooth loss if untreated.",
    "Oral Candidiasis (Thrush)": "Consult a dentist or physician. Antifungal treatment may be required.",
    "Tooth Abscess": "Urgent dental care needed. An abscess can spread infection — contact a dentist immediately.",
    "Mouth Ulcers (Canker Sores)": "Use a soft-bristled brush, avoid spicy foods, and monitor for persistent ulcers beyond 2 weeks.",
    "Healthy": "Maintain good oral hygiene and schedule regular dental check-ups every 6 months.",
}


class SymptomInput(BaseModel):
    toothache: int = Field(0, ge=0, le=1)
    hot_cold_sensitivity: int = Field(0, ge=0, le=1)
    swollen_gums: int = Field(0, ge=0, le=1)
    bleeding_gums: int = Field(0, ge=0, le=1)
    bad_breath: int = Field(0, ge=0, le=1)
    white_patches: int = Field(0, ge=0, le=1)
    loose_teeth: int = Field(0, ge=0, le=1)
    fever: int = Field(0, ge=0, le=1)
    jaw_swelling: int = Field(0, ge=0, le=1)
    pain_when_chewing: int = Field(0, ge=0, le=1)
    mouth_sores: int = Field(0, ge=0, le=1)


def _risk_level(confidence: float, symptom_count: int, disease: str) -> str:
    if disease == "Healthy":
        return "Low"
    if confidence >= 0.85 or symptom_count >= 4:
        return "High"
    if confidence >= 0.65 or symptom_count >= 2:
        return "Medium"
    return "Low"


def _rule_based_analysis(payload: dict) -> dict:
    """Fallback when ML models are not trained yet."""
    count = sum(payload.values())
    s = payload

    if count == 0:
        disease, confidence = "Healthy", 0.5
    elif s["fever"] and (s["jaw_swelling"] or s["toothache"]):
        disease, confidence = "Tooth Abscess", 0.88
    elif s["white_patches"]:
        disease, confidence = "Oral Candidiasis (Thrush)", 0.82
    elif s["loose_teeth"] and (s["bleeding_gums"] or s["swollen_gums"]):
        disease, confidence = "Periodontitis", 0.85
    elif s["bleeding_gums"] or s["swollen_gums"]:
        disease, confidence = "Gingivitis", 0.78
    elif s["mouth_sores"] and count <= 2:
        disease, confidence = "Mouth Ulcers (Canker Sores)", 0.72
    elif s["toothache"] or s["hot_cold_sensitivity"] or s["pain_when_chewing"]:
        disease, confidence = "Dental Caries (Cavity)", 0.80
    elif count <= 1:
        disease, confidence = "Healthy", 0.60
    else:
        disease, confidence = "Gingivitis", 0.70

    risk = _risk_level(confidence, count, disease)
    return {
        "predicted_disease": disease,
        "confidence": round(confidence, 4),
        "risk_level": risk,
        "recommendation": RECOMMENDATIONS.get(
            disease,
            "Please consult a certified dentist for a proper clinical examination.",
        ),
        "symptoms_reported": count,
        "source": "rule_based",
    }


@router.post("/")
async def check_symptom(data: SymptomInput):
    payload = data.model_dump()
    symptom_count = sum(payload.values())

    if not _load_models():
        return _rule_based_analysis(payload)

    features = np.array([[payload[key] for key in FEATURE_ORDER]])
    features_scaled = scaler.transform(features)

    prediction = symptom_model.predict(features_scaled)
    proba = symptom_model.predict_proba(features_scaled)
    confidence = float(proba.max())
    disease = label_encoder.inverse_transform(prediction)[0]

    risk = _risk_level(confidence, symptom_count, disease)
    recommendation = RECOMMENDATIONS.get(
        disease,
        "Please consult a certified dentist for a proper clinical examination.",
    )

    return {
        "predicted_disease": disease,
        "confidence": round(confidence, 4),
        "risk_level": risk,
        "recommendation": recommendation,
        "symptoms_reported": symptom_count,
        "source": "ml",
    }
