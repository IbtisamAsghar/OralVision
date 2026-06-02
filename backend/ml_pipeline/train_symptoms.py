import pandas as pd
import numpy as np
import os
import joblib
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder, StandardScaler
from sklearn.linear_model import LogisticRegression
from sklearn.ensemble import RandomForestClassifier
from sklearn.svm import SVC
from sklearn.metrics import accuracy_score, precision_score, recall_score, roc_auc_score

def main():
    print("Loading dataset...")
    # 1. Load Data
    csv_path = os.path.join(os.path.dirname(__file__), 'oral_symptoms_dataset.csv')
    df = pd.read_csv(csv_path)

    # 2. Separate Features and Target
    X = df.drop(columns=['disease'])
    y = df['disease']

    # 3. Preprocessing
    print("Preprocessing data...")
    label_encoder = LabelEncoder()
    y_encoded = label_encoder.fit_transform(y)
    
    # Check classes
    classes = label_encoder.classes_
    print(f"Detected {len(classes)} classes: {classes}")

    # Split
    X_train, X_test, y_train, y_test = train_test_split(X, y_encoded, test_size=0.2, random_state=42, stratify=y_encoded)

    # Scale Features
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled = scaler.transform(X_test)

    # 4. Initialize Models
    models = {
        'Logistic Regression': LogisticRegression(max_iter=1000, multi_class='multinomial'),
        'Random Forest': RandomForestClassifier(n_estimators=100, random_state=42),
        'SVM': SVC(probability=True, random_state=42)
    }

    # 5. Train & Evaluate
    results = {}
    best_model_name = None
    best_model = None
    best_score = 0

    print("\nTraining and Evaluating Models...")
    for name, model in models.items():
        print(f"--> Training {name}...")
        model.fit(X_train_scaled, y_train)
        
        # Predictions
        y_pred = model.predict(X_test_scaled)
        y_prob = model.predict_proba(X_test_scaled)

        # Metrics
        acc = accuracy_score(y_test, y_pred)
        precision = precision_score(y_test, y_pred, average='macro', zero_division=0)
        recall = recall_score(y_test, y_pred, average='macro', zero_division=0)
        
        try:
            auc = roc_auc_score(y_test, y_prob, multi_class='ovr')
        except Exception as e:
            auc = 0.0

        results[name] = {
            'Accuracy': acc,
            'Precision': precision,
            'Recall': recall,
            'AUC': auc
        }

        print(f"    {name} - Accuracy: {acc:.4f} | Recall: {recall:.4f} | AUC: {auc:.4f}")

        # Selection criteria (prioritizing Accuracy and Recall)
        combined_score = acc + recall
        if combined_score > best_score:
            best_score = combined_score
            best_model_name = name
            best_model = model

    print(f"\nBest Model Selected: {best_model_name}")

    # 6. Export Best Model & Preprocessors
    models_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), 'app', 'models')
    os.makedirs(models_dir, exist_ok=True)

    model_path = os.path.join(models_dir, 'best_model.pkl')
    scaler_path = os.path.join(models_dir, 'scaler.pkl')
    le_path = os.path.join(models_dir, 'label_encoder.pkl')

    joblib.dump(best_model, model_path)
    joblib.dump(scaler, scaler_path)
    joblib.dump(label_encoder, le_path)

    print(f"\nPipeline Complete! Artifacts saved to {models_dir}")
    print(f"  - {model_path}")
    print(f"  - {scaler_path}")
    print(f"  - {le_path}")

if __name__ == '__main__':
    main()
