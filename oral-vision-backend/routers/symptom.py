import os
import joblib
import numpy as np
from fastapi import APIRouter
from pydantic import BaseModel, Field
from typing import Optional

router = APIRouter()

MODEL_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "models", "symptom")

symptom_model = None
scaler = None
label_encoder = None
_models_loaded = False

SYMPTOMS = [
    "toothache", "hot_sensitivity", "cold_sensitivity", "sweet_sensitivity",
    "pain_when_chewing", "loose_tooth", "cracked_tooth", "tooth_discoloration",
    "tooth_mobility", "tooth_grinding", "sharp_pain_biting", "food_stuck",
    "pus_around_tooth", "swollen_gum_around_tooth",
    "bleeding_gums", "red_gums", "swollen_gums", "receding_gums",
    "gum_pain", "bad_breath", "pus_from_gums",
    "mouth_ulcers", "white_patches", "red_patches", "burning_sensation",
    "dry_mouth", "difficulty_swallowing", "tongue_pain", "tongue_swelling",
    "change_in_taste", "loss_of_taste", "thick_saliva", "excessive_saliva",
    "fever", "jaw_swelling", "facial_swelling", "enlarged_lymph_nodes",
    "fatigue", "ear_pain", "headache",
    "non_healing_ulcer", "lump_in_mouth", "lump_in_neck",
    "persistent_mouth_pain", "difficulty_opening_mouth",
    "unexplained_bleeding", "numbness_in_mouth", "hoarseness",
    "weight_loss", "persistent_sore_throat",
]

RECOMMENDATIONS = {
    "Dental Caries": "Avoid sugary foods, brush twice daily with fluoride toothpaste, and schedule a dental filling immediately.",
    "Tooth Abscess": "URGENT: Seek emergency dental care immediately. An abscess can spread to the jaw and neck.",
    "Gingivitis": "Improve oral hygiene, use antiseptic mouthwash daily, and visit a dentist for professional cleaning.",
    "Periodontitis": "Seek immediate periodontal care. Advanced gum disease can lead to tooth loss if untreated.",
    "Pulpitis": "See a dentist immediately. You may need root canal treatment to save the tooth.",
    "Cracked Tooth Syndrome": "Avoid hard foods. See a dentist immediately — a cracked tooth worsens quickly.",
    "Bruxism": "Use a night guard. Consult your dentist about stress management and bite correction.",
    "Oral Thrush": "Antifungal medication required. Consult a dentist or physician as soon as possible.",
    "Aphthous Ulcer": "Use antiseptic mouthwash. Avoid spicy foods. See a dentist if ulcer persists beyond 2 weeks.",
    "Leukoplakia": "IMPORTANT: White patches need biopsy. See a dentist immediately.",
    "Xerostomia": "Stay hydrated, chew sugar-free gum, use alcohol-free mouthwash. Consult your dentist.",
    "Oral Lichen Planus": "Consult a specialist. Oral lichen planus requires monitoring and treatment.",
    "Herpes Simplex (Oral)": "Antiviral medication can help. Avoid contact with others during active outbreak.",
    "Oral Submucous Fibrosis": "Stop tobacco/betel nut use immediately. Requires specialist evaluation.",
    "Oral Cancer": "URGENT: Non-healing ulcers/lumps need immediate biopsy. See an oral surgeon today.",
    "Healthy": "Great oral health! Maintain regular brushing, flossing, and dental check-ups every 6 months.",
}

def _load_models():
    global symptom_model, scaler, label_encoder, _models_loaded
    if _models_loaded:
        return symptom_model is not None
    _models_loaded = True
    try:
        symptom_model = joblib.load(os.path.join(MODEL_DIR, "best_model.pkl"))
        scaler = joblib.load(os.path.join(MODEL_DIR, "scaler.pkl"))
        label_encoder = joblib.load(os.path.join(MODEL_DIR, "symptom_label_encoder.pkl"))
        return True
    except (FileNotFoundError, OSError):
        return False

def _risk_level(confidence: float, symptom_count: int, disease: str) -> str:
    if disease == "Healthy":
        return "Low"
    cancer_diseases = ["Oral Cancer", "Leukoplakia", "Oral Submucous Fibrosis"]
    if disease in cancer_diseases:
        return "Critical"
    urgent = ["Tooth Abscess", "Periodontitis", "Pulpitis"]
    if disease in urgent or confidence >= 0.85 or symptom_count >= 6:
        return "High"
    if confidence >= 0.65 or symptom_count >= 3:
        return "Medium"
    return "Low"

def _rule_based(s: dict) -> dict:
    count = sum(s.values())
    disease, confidence = "Healthy", 0.95

    if count == 0:
        disease, confidence = "Healthy", 0.97
    elif s.get("non_healing_ulcer") or s.get("lump_in_mouth") or s.get("lump_in_neck"):
        disease, confidence = "Oral Cancer", 0.91
    elif s.get("difficulty_opening_mouth") and s.get("white_patches"):
        disease, confidence = "Oral Submucous Fibrosis", 0.88
    elif s.get("fever") and (s.get("jaw_swelling") or s.get("pus_around_tooth")):
        disease, confidence = "Tooth Abscess", 0.93
    elif s.get("white_patches") and s.get("non_healing_ulcer"):
        disease, confidence = "Leukoplakia", 0.89
    elif s.get("white_patches") and s.get("burning_sensation"):
        disease, confidence = "Oral Thrush", 0.86
    elif s.get("white_patches") and s.get("red_patches"):
        disease, confidence = "Oral Lichen Planus", 0.84
    elif s.get("cracked_tooth") and s.get("sharp_pain_biting"):
        disease, confidence = "Cracked Tooth Syndrome", 0.88
    elif s.get("loose_tooth") and (s.get("receding_gums") or s.get("pus_from_gums")):
        disease, confidence = "Periodontitis", 0.87
    elif s.get("toothache") and s.get("hot_sensitivity") and s.get("sharp_pain_biting"):
        disease, confidence = "Pulpitis", 0.86
    elif s.get("tooth_grinding") and s.get("headache"):
        disease, confidence = "Bruxism", 0.83
    elif s.get("dry_mouth") and s.get("thick_saliva"):
        disease, confidence = "Xerostomia", 0.82
    elif s.get("bleeding_gums") and s.get("swollen_gums"):
        disease, confidence = "Gingivitis", 0.82
    elif s.get("mouth_ulcers") and s.get("fever"):
        disease, confidence = "Herpes Simplex (Oral)", 0.80
    elif s.get("mouth_ulcers"):
        disease, confidence = "Aphthous Ulcer", 0.78
    elif s.get("toothache") or s.get("cold_sensitivity"):
        disease, confidence = "Dental Caries", 0.80
    elif count >= 5:
        disease, confidence = "Periodontitis", 0.72
    elif count >= 2:
        disease, confidence = "Gingivitis", 0.68

    risk = _risk_level(confidence, count, disease)
    return {
        "predicted_disease": disease,
        "confidence": round(confidence, 4),
        "risk_level": risk,
        "recommendation": RECOMMENDATIONS.get(disease, "Please consult a certified dentist."),
        "symptoms_reported": count,
        "source": "rule_based",
    }

class SymptomInput(BaseModel):
    toothache: int = Field(0, ge=0, le=1)
    hot_sensitivity: int = Field(0, ge=0, le=1)
    cold_sensitivity: int = Field(0, ge=0, le=1)
    sweet_sensitivity: int = Field(0, ge=0, le=1)
    pain_when_chewing: int = Field(0, ge=0, le=1)
    loose_tooth: int = Field(0, ge=0, le=1)
    cracked_tooth: int = Field(0, ge=0, le=1)
    tooth_discoloration: int = Field(0, ge=0, le=1)
    tooth_mobility: int = Field(0, ge=0, le=1)
    tooth_grinding: int = Field(0, ge=0, le=1)
    sharp_pain_biting: int = Field(0, ge=0, le=1)
    food_stuck: int = Field(0, ge=0, le=1)
    pus_around_tooth: int = Field(0, ge=0, le=1)
    swollen_gum_around_tooth: int = Field(0, ge=0, le=1)
    bleeding_gums: int = Field(0, ge=0, le=1)
    red_gums: int = Field(0, ge=0, le=1)
    swollen_gums: int = Field(0, ge=0, le=1)
    receding_gums: int = Field(0, ge=0, le=1)
    gum_pain: int = Field(0, ge=0, le=1)
    bad_breath: int = Field(0, ge=0, le=1)
    pus_from_gums: int = Field(0, ge=0, le=1)
    mouth_ulcers: int = Field(0, ge=0, le=1)
    white_patches: int = Field(0, ge=0, le=1)
    red_patches: int = Field(0, ge=0, le=1)
    burning_sensation: int = Field(0, ge=0, le=1)
    dry_mouth: int = Field(0, ge=0, le=1)
    difficulty_swallowing: int = Field(0, ge=0, le=1)
    tongue_pain: int = Field(0, ge=0, le=1)
    tongue_swelling: int = Field(0, ge=0, le=1)
    change_in_taste: int = Field(0, ge=0, le=1)
    loss_of_taste: int = Field(0, ge=0, le=1)
    thick_saliva: int = Field(0, ge=0, le=1)
    excessive_saliva: int = Field(0, ge=0, le=1)
    fever: int = Field(0, ge=0, le=1)
    jaw_swelling: int = Field(0, ge=0, le=1)
    facial_swelling: int = Field(0, ge=0, le=1)
    enlarged_lymph_nodes: int = Field(0, ge=0, le=1)
    fatigue: int = Field(0, ge=0, le=1)
    ear_pain: int = Field(0, ge=0, le=1)
    headache: int = Field(0, ge=0, le=1)
    non_healing_ulcer: int = Field(0, ge=0, le=1)
    lump_in_mouth: int = Field(0, ge=0, le=1)
    lump_in_neck: int = Field(0, ge=0, le=1)
    persistent_mouth_pain: int = Field(0, ge=0, le=1)
    difficulty_opening_mouth: int = Field(0, ge=0, le=1)
    unexplained_bleeding: int = Field(0, ge=0, le=1)
    numbness_in_mouth: int = Field(0, ge=0, le=1)
    hoarseness: int = Field(0, ge=0, le=1)
    weight_loss: int = Field(0, ge=0, le=1)
    persistent_sore_throat: int = Field(0, ge=0, le=1)

@router.post("/")
async def check_symptom(data: SymptomInput):
    payload = data.model_dump()
    symptom_count = sum(payload.values())

    if not _load_models():
        return _rule_based(payload)

    try:
        features = np.array([[payload[s] for s in SYMPTOMS]])
        features_scaled = scaler.transform(features)
        prediction = symptom_model.predict(features_scaled)
        proba = symptom_model.predict_proba(features_scaled)
        confidence = float(proba.max())
        disease = label_encoder.inverse_transform(prediction)[0]
        risk = _risk_level(confidence, symptom_count, disease)
        return {
            "predicted_disease": disease,
            "confidence": round(confidence, 4),
            "risk_level": risk,
            "recommendation": RECOMMENDATIONS.get(disease, "Please consult a certified dentist."),
            "symptoms_reported": symptom_count,
            "source": "ml",
        }
    except Exception:
        return _rule_based(payload)