from fastapi import APIRouter, HTTPException, BackgroundTasks
from pydantic import BaseModel
from typing import Dict
import uuid
import logging
from app.services.ml_service import predict_symptoms
from app.services.gemini_service import generate_report
from app.services.pdf_service import create_pdf
from app.services.supabase_service import get_deterministic_pdf_url, upload_and_save_record_bg

logger = logging.getLogger(__name__)

router = APIRouter(
    prefix="/predict",
    tags=["Predictions"]
)

class SymptomRequest(BaseModel):
    patient_id: str
    symptoms: Dict[str, int]

def run_deferred_tasks(
    assessment_uuid: str,
    patient_id: str,
    symptoms: dict,
    disease: str,
    confidence: float,
    severity: str,
    ai_report: str
):
    """
    Worker task to compile PDF, upload to Supabase storage,
    and save log to Supabase DB. Executed in the background.
    """
    try:
        logger.info(f"Starting background PDF generation and Supabase upload for {assessment_uuid}...")
        pdf_path = create_pdf(disease, confidence, severity, ai_report)
        upload_and_save_record_bg(
            assessment_uuid=assessment_uuid,
            patient_id=patient_id,
            symptoms=symptoms,
            disease=disease,
            confidence=confidence,
            severity=severity,
            ai_report=ai_report,
            pdf_path=pdf_path
        )
        logger.info(f"Background tasks completed successfully for assessment {assessment_uuid}")
    except Exception as e:
        logger.error(f"Error executing deferred background task for assessment {assessment_uuid}: {e}")

@router.post("/symptoms")
async def predict_oral_symptoms(request: SymptomRequest, background_tasks: BackgroundTasks):
    try:
        # Generate deterministic assessment ID
        assessment_uuid = str(uuid.uuid4())
        
        # 1. Machine Learning Prediction (Local model: ~10ms)
        disease, confidence, severity = predict_symptoms(request.symptoms)
        
        # 2. Generative AI Report (Gemini API / Healthy Gating: ~1.5s)
        ai_report = generate_report(request.symptoms, disease, confidence, severity)
        
        # 3. Calculate Deterministic PDF URL synchronously
        pdf_url = get_deterministic_pdf_url(request.patient_id, assessment_uuid)
        
        # 4. Defer PDF generation, Supabase storage upload, and DB insert to background task
        background_tasks.add_task(
            run_deferred_tasks,
            assessment_uuid,
            request.patient_id,
            request.symptoms,
            disease,
            confidence,
            severity,
            ai_report
        )
        
        return {
            "status": "success",
            "data": {
                "id": assessment_uuid,
                "disease": disease,
                "confidence": confidence,
                "severity": severity,
                "ai_report": ai_report,
                "pdf_url": pdf_url
            }
        }
        
    except Exception as e:
        logger.error(f"Error processing symptom prediction: {e}")
        raise HTTPException(status_code=500, detail=str(e))
