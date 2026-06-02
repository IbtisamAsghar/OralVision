from supabase import create_client, Client
import os
import uuid
import json
import logging

logger = logging.getLogger(__name__)

def get_supabase() -> Client:
    url = os.getenv("SUPABASE_URL")
    # Best practice is to use service role key for backend-driven inserts
    key = os.getenv("SUPABASE_SERVICE_ROLE_KEY") or os.getenv("SUPABASE_ANON_KEY")
    
    if not url or not key:
        raise ValueError("Missing SUPABASE configuration in environment variables.")
    return create_client(url, key)

def get_deterministic_pdf_url(patient_id: str, assessment_uuid: str) -> str:
    url = os.getenv("SUPABASE_URL")
    if not url:
        raise ValueError("Missing SUPABASE_URL in environment variables.")
    base_url = url.rstrip('/')
    return f"{base_url}/storage/v1/object/public/patient_reports/{patient_id}/{assessment_uuid}.pdf"

def upload_and_save_record(
    patient_id: str, 
    symptoms: dict, 
    disease: str, 
    confidence: float, 
    severity: str, 
    ai_report: str, 
    pdf_path: str
) -> str:
    
    supabase = get_supabase()
    file_name = f"{patient_id}/{uuid.uuid4()}.pdf"
    pdf_url = ""
    
    # 1. Upload PDF to Storage
    try:
        logger.info(f"Uploading PDF to Supabase Storage: {file_name}")
        try:
            supabase.storage.create_bucket("patient_reports", options={"public": True})
        except Exception:
            pass
            
        with open(pdf_path, "rb") as f:
            supabase.storage.from_("patient_reports").upload(
                file_name, 
                f, 
                file_options={"content-type": "application/pdf"}
            )
        pdf_url = supabase.storage.from_("patient_reports").get_public_url(file_name)
    except Exception as e:
        logger.error(f"Failed to upload PDF: {e}")
        
    # Clean up local PDF
    if os.path.exists(pdf_path):
        os.remove(pdf_path)
        
    # 2. Insert Record into DB
    record = {
        "patient_id": patient_id,
        "symptoms_json": json.dumps(symptoms),
        "disease_class": disease,
        "confidence_score": confidence,
        "severity": severity,
        "ai_report_text": ai_report,
        "pdf_url": pdf_url
    }
    
    try:
        logger.info("Inserting assessment record into symptom_assessments table...")
        supabase.table("symptom_assessments").insert(record).execute()
    except Exception as e:
        logger.error(f"Error inserting record into Supabase: {e}")
        
    return pdf_url

def upload_and_save_record_bg(
    assessment_uuid: str,
    patient_id: str, 
    symptoms: dict, 
    disease: str, 
    confidence: float, 
    severity: str, 
    ai_report: str, 
    pdf_path: str
) -> None:
    """
    Background worker task to upload PDF to storage and save record to Supabase.
    Runs asynchronously after FastAPI handles response.
    """
    supabase = get_supabase()
    file_name = f"{patient_id}/{assessment_uuid}.pdf"
    
    pdf_url = get_deterministic_pdf_url(patient_id, assessment_uuid)
    
    # 1. Upload PDF to Storage
    try:
        logger.info(f"Uploading PDF to Supabase Storage in background: {file_name}")
        try:
            supabase.storage.create_bucket("patient_reports", options={"public": True})
        except Exception:
            pass

        with open(pdf_path, "rb") as f:
            supabase.storage.from_("patient_reports").upload(
                file_name, 
                f, 
                file_options={"content-type": "application/pdf"}
            )
    except Exception as e:
        logger.error(f"Failed to upload PDF in background: {e}")
        
    # Clean up local PDF
    if os.path.exists(pdf_path):
        try:
            os.remove(pdf_path)
        except Exception as cleanup_error:
            logger.error(f"Failed to delete local temporary PDF: {cleanup_error}")
        
    # 2. Insert Record into DB
    record = {
        "id": assessment_uuid,
        "patient_id": patient_id,
        "symptoms_json": json.dumps(symptoms),
        "disease_class": disease,
        "confidence_score": confidence,
        "severity": severity,
        "ai_report_text": ai_report,
        "pdf_url": pdf_url
    }
    
    try:
        logger.info("Inserting assessment record into symptom_assessments in background...")
        supabase.table("symptom_assessments").insert(record).execute()
        logger.info("Successfully stored assessment record in background.")
    except Exception as e:
        logger.error(f"Error inserting record into Supabase in background: {e}")

