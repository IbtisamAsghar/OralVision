import pandas as pd
import numpy as np
import random
import os

# Create backend and ml_pipeline directories if they don't exist
os.makedirs('backend/ml_pipeline', exist_ok=True)

# Define the clinical diseases
diseases = [
    'Dental Caries (Cavity)', 
    'Gingivitis', 
    'Periodontitis', 
    'Oral Candidiasis (Thrush)', 
    'Tooth Abscess', 
    'Mouth Ulcers (Canker Sores)',
    'Healthy'
]

# Define the symptoms (features)
symptoms = [
    'toothache',
    'hot_cold_sensitivity',
    'swollen_gums',
    'bleeding_gums',
    'bad_breath',
    'white_patches',
    'loose_teeth',
    'fever',
    'jaw_swelling',
    'pain_when_chewing',
    'mouth_sores'
]

def generate_record():
    disease = random.choice(diseases)
    record = {s: 0 for s in symptoms}
    
    if disease == 'Dental Caries (Cavity)':
        record['toothache'] = random.choices([1, 0], weights=[0.9, 0.1])[0]
        record['hot_cold_sensitivity'] = random.choices([1, 0], weights=[0.95, 0.05])[0]
        record['pain_when_chewing'] = random.choices([1, 0], weights=[0.8, 0.2])[0]
        record['bad_breath'] = random.choices([1, 0], weights=[0.4, 0.6])[0]
        
    elif disease == 'Gingivitis':
        record['swollen_gums'] = random.choices([1, 0], weights=[0.95, 0.05])[0]
        record['bleeding_gums'] = random.choices([1, 0], weights=[0.95, 0.05])[0]
        record['bad_breath'] = random.choices([1, 0], weights=[0.7, 0.3])[0]
        record['hot_cold_sensitivity'] = random.choices([1, 0], weights=[0.3, 0.7])[0]
        
    elif disease == 'Periodontitis':
        record['swollen_gums'] = 1
        record['bleeding_gums'] = 1
        record['loose_teeth'] = random.choices([1, 0], weights=[0.85, 0.15])[0]
        record['bad_breath'] = random.choices([1, 0], weights=[0.9, 0.1])[0]
        record['pain_when_chewing'] = random.choices([1, 0], weights=[0.6, 0.4])[0]
        
    elif disease == 'Oral Candidiasis (Thrush)':
        record['white_patches'] = random.choices([1, 0], weights=[0.99, 0.01])[0]
        record['mouth_sores'] = random.choices([1, 0], weights=[0.5, 0.5])[0]
        record['bad_breath'] = random.choices([1, 0], weights=[0.4, 0.6])[0]
        
    elif disease == 'Tooth Abscess':
        record['toothache'] = 1
        record['jaw_swelling'] = random.choices([1, 0], weights=[0.9, 0.1])[0]
        record['fever'] = random.choices([1, 0], weights=[0.8, 0.2])[0]
        record['pain_when_chewing'] = 1
        record['hot_cold_sensitivity'] = 1
        
    elif disease == 'Mouth Ulcers (Canker Sores)':
        record['mouth_sores'] = 1
        record['pain_when_chewing'] = random.choices([1, 0], weights=[0.7, 0.3])[0]
        
    elif disease == 'Healthy':
        # All 0, occasionally random rare 1 just for noise
        for s in symptoms:
            record[s] = random.choices([1, 0], weights=[0.02, 0.98])[0]
            
    record['disease'] = disease
    return record

print("Generating clinical dataset...")
data = [generate_record() for _ in range(2500)]
df = pd.DataFrame(data)

csv_path = 'backend/ml_pipeline/oral_symptoms_dataset.csv'
df.to_csv(csv_path, index=False)
print(f"Successfully generated {len(df)} records at {csv_path}")
