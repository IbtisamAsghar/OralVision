import google.generativeai as genai
import os
import json

def generate_report(symptoms: dict, disease: str, confidence: float, severity: str) -> str:
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        return "AI Report generation is unavailable. Please configure GEMINI_API_KEY."
    
    genai.configure(api_key=api_key)
    
    # Use a flash-lite model to utilize a higher free tier quota and avoid limit issues
    model = genai.GenerativeModel('gemini-2.5-flash-lite')
    
    # Filter only the active symptoms to provide context to the LLM
    active_symptoms = [k.replace('_', ' ') for k, v in symptoms.items() if v == 1]
    
    prompt = f"""
    You are an expert AI dental assistant for the application 'OralVision'. 
    A patient has reported the following active symptoms: {', '.join(active_symptoms)}.
    
    Our proprietary ML model predicts the condition is '{disease}' with a confidence score of {confidence:.1%} and a clinical severity of '{severity}'.
    
    Write a highly professional, empathetic, and patient-friendly medical report. 
    Include exactly these three sections:
    1. Condition Summary: A brief explanation of what the condition is.
    2. Recommended Next Steps: Actionable advice (e.g., home care routines, or urgency to visit a dentist).
    3. Disclaimer: A strict medical disclaimer stating this is an AI prediction and not a formal diagnosis.
    
    Keep the report under 200 words. Do not use markdown formatting like asterisks or hashtags, use plain text.
    """
    
    try:
        response = model.generate_content(prompt)
        return response.text
    except Exception as e:
        # Fallback to a structured local template if the API is rate-limited (429) or offline
        fallback_report = f"Condition Summary: Based on your symptoms, our ML model predicts a likely condition of {disease} with {confidence:.1%} confidence. The clinical severity is considered {severity}.\n\nRecommended Next Steps:\n1. Maintain thorough daily oral hygiene (brushing twice daily and flossing).\n2. Schedule an appointment with a dental professional for a comprehensive examination.\n3. Avoid self-medicating or neglecting persisting pain or swelling.\n\nDisclaimer: This report is an AI-assisted prediction based on self-reported symptoms. It is not a formal medical diagnosis or a substitute for professional clinical advice."
        return fallback_report
