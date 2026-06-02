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
