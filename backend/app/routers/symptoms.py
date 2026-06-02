from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Dict
from app.services.ml_service import predict_symptoms
from app.services.gemini_service import generate_report
from app.services.pdf_service import create_pdf
from app.services.supabase_service import upload_and_save_record

router = APIRouter(
    prefix="/predict",
    tags=["Predictions"]
)

class SymptomRequest(BaseModel):
    patient_id: str
    symptoms: Dict[str, int]

@router.post("/symptoms")
async def predict_oral_symptoms(request: SymptomRequest):
    try:
        # 1. Machine Learning Prediction
        disease, confidence, severity = predict_symptoms(request.symptoms)
        
        # 2. Generative AI Report
        ai_report = generate_report(request.symptoms, disease, confidence, severity)
        
        # 3. PDF Formatting
        pdf_path = create_pdf(disease, confidence, severity, ai_report)
        
        # 4. Cloud Storage & Database Persistence
        pdf_url = upload_and_save_record(
            patient_id=request.patient_id,
            symptoms=request.symptoms,
            disease=disease,
            confidence=confidence,
            severity=severity,
            ai_report=ai_report,
            pdf_path=pdf_path
        )
        
        return {
            "status": "success",
            "data": {
                "disease": disease,
                "confidence": confidence,
                "severity": severity,
                "ai_report": ai_report,
                "pdf_url": pdf_url
            }
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
