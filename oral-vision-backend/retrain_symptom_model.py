import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
from sklearn.preprocessing import LabelEncoder, StandardScaler
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, classification_report
import joblib
import os

# ── 50 symptoms ──────────────────────────────────────────────────
SYMPTOMS = [
    # Dental
    "toothache", "hot_sensitivity", "cold_sensitivity", "sweet_sensitivity",
    "pain_when_chewing", "loose_tooth", "cracked_tooth", "tooth_discoloration",
    "tooth_mobility", "tooth_grinding", "sharp_pain_biting", "food_stuck",
    "pus_around_tooth", "swollen_gum_around_tooth",
    # Gum
    "bleeding_gums", "red_gums", "swollen_gums", "receding_gums",
    "gum_pain", "bad_breath", "pus_from_gums",
    # Oral
    "mouth_ulcers", "white_patches", "red_patches", "burning_sensation",
    "dry_mouth", "difficulty_swallowing", "tongue_pain", "tongue_swelling",
    "change_in_taste", "loss_of_taste", "thick_saliva", "excessive_saliva",
    # Infection
    "fever", "jaw_swelling", "facial_swelling", "enlarged_lymph_nodes",
    "fatigue", "ear_pain", "headache",
    # Oral Cancer Screening
    "non_healing_ulcer", "lump_in_mouth", "lump_in_neck",
    "persistent_mouth_pain", "difficulty_opening_mouth",
    "unexplained_bleeding", "numbness_in_mouth", "hoarseness",
    # General
    "weight_loss", "persistent_sore_throat",
]

# ── 16 diseases ──────────────────────────────────────────────────
DISEASES = [
    "Dental Caries",
    "Tooth Abscess",
    "Gingivitis",
    "Periodontitis",
    "Pulpitis",
    "Cracked Tooth Syndrome",
    "Bruxism",
    "Oral Thrush",
    "Aphthous Ulcer",
    "Leukoplakia",
    "Xerostomia",
    "Oral Lichen Planus",
    "Herpes Simplex (Oral)",
    "Oral Submucous Fibrosis",
    "Oral Cancer",
    "Healthy",
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
    "Leukoplakia": "IMPORTANT: White patches that don't wipe off need biopsy. See a dentist immediately.",
    "Xerostomia": "Stay hydrated, chew sugar-free gum, use alcohol-free mouthwash. Consult your dentist.",
    "Oral Lichen Planus": "Consult a specialist. Oral lichen planus requires monitoring and may need treatment.",
    "Herpes Simplex (Oral)": "Antiviral medication can help. Avoid contact with others during active outbreak.",
    "Oral Submucous Fibrosis": "Stop tobacco/betel nut use immediately. Requires specialist evaluation.",
    "Oral Cancer": "URGENT: Non-healing ulcers/lumps need immediate biopsy. See an oral surgeon today.",
    "Healthy": "Great oral health! Maintain regular brushing, flossing, and dental check-ups every 6 months.",
}

# ── Disease symptom profiles ──────────────────────────────────────
def make_profile(primary, secondary, n=400, noise=0.08):
    rows = []
    for _ in range(n):
        row = {s: 0 for s in SYMPTOMS}
        for s in primary:
            row[s] = 1
        for s in secondary:
            row[s] = 1 if np.random.random() > 0.35 else 0
        # add random noise
        for s in SYMPTOMS:
            if row[s] == 0 and np.random.random() < noise:
                row[s] = 1
        rows.append(row)
    return rows

profiles = {
    "Dental Caries": make_profile(
        primary=["toothache", "cold_sensitivity", "hot_sensitivity", "pain_when_chewing"],
        secondary=["sweet_sensitivity", "food_stuck", "tooth_discoloration", "bad_breath"]
    ),
    "Tooth Abscess": make_profile(
        primary=["toothache", "fever", "jaw_swelling", "pus_around_tooth"],
        secondary=["facial_swelling", "enlarged_lymph_nodes", "headache", "ear_pain", "fatigue", "pain_when_chewing"]
    ),
    "Gingivitis": make_profile(
        primary=["bleeding_gums", "swollen_gums", "red_gums"],
        secondary=["bad_breath", "gum_pain", "swollen_gum_around_tooth"]
    ),
    "Periodontitis": make_profile(
        primary=["loose_tooth", "receding_gums", "pus_from_gums", "bleeding_gums"],
        secondary=["bad_breath", "gum_pain", "tooth_mobility", "swollen_gums", "food_stuck"]
    ),
    "Pulpitis": make_profile(
        primary=["toothache", "hot_sensitivity", "cold_sensitivity", "sharp_pain_biting"],
        secondary=["pain_when_chewing", "swollen_gum_around_tooth", "pus_around_tooth"]
    ),
    "Cracked Tooth Syndrome": make_profile(
        primary=["cracked_tooth", "sharp_pain_biting", "pain_when_chewing"],
        secondary=["cold_sensitivity", "hot_sensitivity", "toothache"]
    ),
    "Bruxism": make_profile(
        primary=["tooth_grinding", "jaw_swelling", "headache"],
        secondary=["tooth_discoloration", "toothache", "ear_pain", "cracked_tooth", "tooth_mobility"]
    ),
    "Oral Thrush": make_profile(
        primary=["white_patches", "burning_sensation", "change_in_taste"],
        secondary=["dry_mouth", "difficulty_swallowing", "tongue_pain", "thick_saliva"]
    ),
    "Aphthous Ulcer": make_profile(
        primary=["mouth_ulcers", "gum_pain", "burning_sensation"],
        secondary=["difficulty_swallowing", "tongue_pain", "persistent_mouth_pain"]
    ),
    "Leukoplakia": make_profile(
        primary=["white_patches", "non_healing_ulcer"],
        secondary=["burning_sensation", "difficulty_opening_mouth", "persistent_mouth_pain", "numbness_in_mouth"]
    ),
    "Xerostomia": make_profile(
        primary=["dry_mouth", "thick_saliva", "difficulty_swallowing"],
        secondary=["change_in_taste", "bad_breath", "burning_sensation", "loss_of_taste"]
    ),
    "Oral Lichen Planus": make_profile(
        primary=["white_patches", "red_patches", "burning_sensation", "mouth_ulcers"],
        secondary=["gum_pain", "difficulty_swallowing", "change_in_taste"]
    ),
    "Herpes Simplex (Oral)": make_profile(
        primary=["mouth_ulcers", "fever", "burning_sensation"],
        secondary=["tongue_pain", "fatigue", "enlarged_lymph_nodes", "persistent_sore_throat"]
    ),
    "Oral Submucous Fibrosis": make_profile(
        primary=["difficulty_opening_mouth", "burning_sensation", "white_patches"],
        secondary=["difficulty_swallowing", "numbness_in_mouth", "persistent_mouth_pain", "change_in_taste"]
    ),
    "Oral Cancer": make_profile(
        primary=["non_healing_ulcer", "lump_in_mouth", "unexplained_bleeding", "numbness_in_mouth"],
        secondary=["lump_in_neck", "difficulty_opening_mouth", "persistent_mouth_pain",
                   "difficulty_swallowing", "hoarseness", "weight_loss", "persistent_sore_throat"]
    ),
    "Healthy": make_profile(primary=[], secondary=[], n=300, noise=0.02),
}

# ── Build dataset ─────────────────────────────────────────────────
all_rows = []
all_labels = []
for disease, rows in profiles.items():
    all_rows.extend(rows)
    all_labels.extend([disease] * len(rows))

df = pd.DataFrame(all_rows, columns=SYMPTOMS)
df["disease"] = all_labels
df = df.sample(frac=1, random_state=42).reset_index(drop=True)

X = df[SYMPTOMS].values
y = df["disease"].values

# ── Encode & scale ────────────────────────────────────────────────
le = LabelEncoder()
y_enc = le.fit_transform(y)
scaler = StandardScaler()
X_scaled = scaler.fit_transform(X)

X_train, X_test, y_train, y_test = train_test_split(X_scaled, y_enc, test_size=0.2, random_state=42, stratify=y_enc)

# ── Train ─────────────────────────────────────────────────────────
print("Training model...")
model = RandomForestClassifier(n_estimators=300, max_depth=20, min_samples_split=3, random_state=42, n_jobs=-1)
model.fit(X_train, y_train)

y_pred = model.predict(X_test)
acc = accuracy_score(y_test, y_pred)
print(f"Accuracy: {acc:.4f}")
print(classification_report(y_test, y_pred, target_names=le.classes_))

# ── Save ──────────────────────────────────────────────────────────
out = os.path.join(os.path.dirname(__file__), "models", "symptom")
os.makedirs(out, exist_ok=True)
joblib.dump(model, os.path.join(out, "best_model.pkl"))
joblib.dump(scaler, os.path.join(out, "scaler.pkl"))
joblib.dump(le, os.path.join(out, "symptom_label_encoder.pkl"))
print("Models saved!")
print("Classes:", list(le.classes_))