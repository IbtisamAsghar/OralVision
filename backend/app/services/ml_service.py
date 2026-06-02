import numpy as np
import pandas as pd
from typing import Dict, Tuple

def predict_symptoms(symptoms: Dict[str, int]) -> Tuple[str, float, str]:
    # Local import to avoid circular dependency
    from app.main import ml_models

    feature_names = [
        'toothache', 'hot_cold_sensitivity', 'swollen_gums', 'bleeding_gums',
        'bad_breath', 'white_patches', 'loose_teeth', 'fever', 'jaw_swelling',
        'pain_when_chewing', 'mouth_sores'
    ]
    
    # Create feature matrix mapping exact features in order
    input_data = {feat: [symptoms.get(feat, 0)] for feat in feature_names}
    input_df = pd.DataFrame(input_data)
    
    if not ml_models or "model" not in ml_models:
        raise RuntimeError("ML Models not loaded in memory. Server might still be starting.")
        
    scaler = ml_models["scaler"]
    model = ml_models["model"]
    encoder = ml_models["encoder"]
    
    input_scaled = scaler.transform(input_df)
    
    # Predict probabilities
    prob = model.predict_proba(input_scaled)[0]
    pred_idx = np.argmax(prob)
    confidence = float(prob[pred_idx])
    disease = encoder.inverse_transform([pred_idx])[0]
    
    # Clinical Severity mapping
    severity_map = {
        'Dental Caries (Cavity)': 'Moderate',
        'Gingivitis': 'Low',
        'Periodontitis': 'High',
        'Oral Candidiasis (Thrush)': 'Moderate',
        'Tooth Abscess': 'Extreme',
        'Mouth Ulcers (Canker Sores)': 'Low',
        'Healthy': 'Low'
    }
    severity = severity_map.get(disease, 'Moderate')
    
    return disease, confidence, severity
