from fpdf import FPDF
import tempfile
import os

def create_pdf(disease: str, confidence: float, severity: str, ai_report: str) -> str:
    pdf = FPDF()
    pdf.add_page()
    
    # Title
    pdf.set_font("Helvetica", 'B', 16)
    pdf.cell(0, 10, txt="OralVision - AI Symptom Assessment Report", align='C')
    pdf.ln(15)
    
    # Results Section
    pdf.set_font("Helvetica", 'B', 12)
    pdf.cell(0, 10, txt=f"Predicted Condition: {disease}")
    pdf.ln(8)
    pdf.cell(0, 10, txt=f"Severity Level: {severity}")
    pdf.ln(8)
    pdf.cell(0, 10, txt=f"AI Confidence Score: {confidence:.1%}")
    pdf.ln(15)
    
    # AI Report Section
    pdf.set_font("Helvetica", 'B', 12)
    pdf.cell(0, 10, txt="Detailed AI Assessment:")
    pdf.ln(10)
    
    pdf.set_font("Helvetica", '', 11)
    
    # Clean up text just in case Gemini sends weird characters
    clean_report = ai_report.encode('latin-1', 'replace').decode('latin-1')
    pdf.multi_cell(0, 8, txt=clean_report)
    
    # Save to temp file
    temp_dir = tempfile.gettempdir()
    # Create a unique filename
    file_path = os.path.join(temp_dir, f"oralvision_report_{os.urandom(4).hex()}.pdf")
    pdf.output(file_path)
    
    return file_path
