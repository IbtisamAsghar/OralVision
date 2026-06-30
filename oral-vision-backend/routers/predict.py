from fastapi import APIRouter, File, UploadFile, HTTPException
from PIL import Image, ImageFilter, ImageDraw
import io, torch, torch.nn as nn, numpy as np, traceback, base64
from torchvision import transforms
from utils.model_loader import (
    load_yolo, load_yolo_seg,
    load_efficientnet_oral
)

router = APIRouter()
MODELS_LOADED = False
MODEL_ERROR = ""
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")

# MODEL LOADING

try:
    yolo_xray             = load_yolo()
    yolo_seg              = load_yolo_seg()
    eff_oral, oral_labels = load_efficientnet_oral()
    eff_oral.to(device)
    eff_oral.eval()
    MODELS_LOADED = True
except Exception as e:
    MODEL_ERROR = traceback.format_exc()

clf_tf = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize([0.485,0.456,0.406],[0.229,0.224,0.225])
])

# IMAGE VALIDATORS

def _is_likely_oral_image(img: Image.Image) -> tuple[bool, str]:
    arr = np.array(img.convert("RGB")).astype(np.float32)
    h, w, _ = arr.shape
    r, g, b = arr[:,:,0], arr[:,:,1], arr[:,:,2]
    white_mask = (r > 220) & (g > 220) & (b > 220)
    black_mask = (r < 35)  & (g < 35)  & (b < 35)
    if (white_mask.sum() + black_mask.sum()) / (h * w) > 0.45:
        return False, "Image appears to be a screenshot or document, not an oral photo."
    max_rgb = arr.max(axis=2)
    saturation = np.where(max_rgb > 0, (max_rgb - arr.min(axis=2)) / (max_rgb + 1e-6), 0)
    if saturation.mean() < 0.08:
        return False, "Image appears to be greyscale or an X-ray. Use the X-Ray tab for dental X-rays."
    skin_mask = (r > 100) & (r > g * 1.05) & (r > b * 1.1) & (g > 40) & (b > 20)
    if skin_mask.sum() / (h * w) < 0.10:
        return False, "No oral tissue detected. Please upload a clear intraoral photo."
    if arr.mean() < 40:
        return False, "Image is too dark. Please upload a well-lit oral photo."
    return True, ""

def _is_likely_xray_image(img: Image.Image) -> tuple[bool, str]:
    arr = np.array(img.convert("RGB")).astype(np.float32)
    h, w, _ = arr.shape
    r, g, b = arr[:,:,0], arr[:,:,1], arr[:,:,2]
    color_diff = (np.abs(r-g).mean() + np.abs(r-b).mean() + np.abs(g-b).mean()) / 3
    if color_diff > 18:
        return False, "Image appears to be a color photo, not an X-ray. Use the Oral Photo tab instead."
    grey = np.array(img.convert("L")).astype(np.float32)
    if grey.std() < 30:
        return False, "Image has too little contrast to be an X-ray. Please upload a clear dental X-ray."
    if ((grey > 252).sum() + (grey < 3).sum()) / grey.size > 0.55:
        return False, "Image appears to be a screenshot, not a dental X-ray."
    skin_mask = (r > 120) & (r > g * 1.1) & (r > b * 1.15) & (g > 60)
    if skin_mask.sum() / (h * w) > 0.20:
        return False, "Image appears to be a color oral photo. Use the Oral Photo tab instead."
    return True, ""

# DISEASE INFO

DISEASE_INFO = {
    "calculus": {
        "description": "Calculus (tartar) is hardened plaque that forms on teeth and gum lines. It cannot be removed by brushing alone and requires professional cleaning.",
        "symptoms": "Yellow/brown deposits on teeth, gum irritation, bad breath",
        "treatment": "Professional dental scaling and polishing",
        "urgency": "Within 1 month",
        "recommendation": "Professional dental scaling required. Improve brushing and flossing routine.",
    },
    "caries": {
        "description": "Dental caries (cavities) is tooth decay caused by bacterial acid erosion of tooth enamel.",
        "symptoms": "Tooth sensitivity, visible holes, pain when eating sweet/hot/cold foods",
        "treatment": "Dental filling or crown depending on severity",
        "urgency": "Within 2 weeks",
        "recommendation": "Schedule a dental appointment for filling evaluation. Avoid sugary foods and brush twice daily with fluoride toothpaste.",
    },
    "gingivitis": {
        "description": "Gingivitis is early-stage gum disease caused by plaque buildup along the gum line.",
        "symptoms": "Red, swollen, bleeding gums especially when brushing",
        "treatment": "Professional cleaning, improved oral hygiene",
        "urgency": "Within 2 weeks",
        "recommendation": "Improve oral hygiene. Professional cleaning and antiseptic mouthwash recommended.",
    },
    "hypodontia": {
        "description": "Hypodontia is a condition where one or more teeth are congenitally missing.",
        "symptoms": "Visible gaps in teeth, misaligned surrounding teeth",
        "treatment": "Dental implants, bridges, or dentures",
        "urgency": "Consult within 1 month",
        "recommendation": "Consult a dentist about tooth replacement options such as implants or bridges.",
    },
    "mouth_ulcer": {
        "description": "Mouth ulcers are painful sores that appear on the mucous membranes inside the mouth.",
        "symptoms": "Round white/yellow sores with red border, pain when eating or talking",
        "treatment": "Antiseptic mouthwash, avoid spicy foods, topical gel if severe",
        "urgency": "If persists beyond 2 weeks, see a dentist immediately",
        "recommendation": "Avoid spicy foods. Consult a dentist if ulcer persists beyond 2 weeks.",
    },
    "tooth_discoloration": {
        "description": "Tooth discoloration refers to staining or color changes in teeth caused by food, drinks, or medication.",
        "symptoms": "Yellow, brown or grey tinge on tooth surface",
        "treatment": "Professional whitening, veneers, or improved oral hygiene",
        "urgency": "Non-urgent, consult within 3 months",
        "recommendation": "Professional cleaning or whitening may help. Reduce tea, coffee and tobacco.",
    },
    "crown": {
        "description": "A dental crown is a cap placed over a damaged tooth.",
        "symptoms": "N/A - existing restoration detected",
        "treatment": "Monitor for cracks or wear, replace if damaged",
        "urgency": "Routine checkup",
        "recommendation": "Crown detected. Consult your dentist for evaluation and maintenance.",
    },
    "filling": {
        "description": "A dental filling is a restorative material used to repair cavities.",
        "symptoms": "N/A - existing restoration detected",
        "treatment": "Monitor for wear, replace when needed",
        "urgency": "Routine checkup",
        "recommendation": "Existing filling detected. Monitor for wear and consult dentist regularly.",
    },
    "implant": {
        "description": "A dental implant is an artificial tooth root placed in the jaw.",
        "symptoms": "N/A - implant detected",
        "treatment": "Maintain regular cleaning and checkups",
        "urgency": "Routine checkup",
        "recommendation": "Implant detected. Maintain regular dental checkups for implant health.",
    },
    "malaligned": {
        "description": "Malalignment refers to teeth that are not properly positioned in the jaw.",
        "symptoms": "Crooked teeth, difficulty chewing, jaw pain",
        "treatment": "Orthodontic treatment (braces or aligners)",
        "urgency": "Consult within 1 month",
        "recommendation": "Malaligned teeth detected. Consult an orthodontist for correction options.",
    },
    "missing": {
        "description": "Missing teeth can affect chewing, speech and cause surrounding teeth to shift.",
        "symptoms": "Visible gap, difficulty chewing",
        "treatment": "Implant, bridge or partial denture",
        "urgency": "Consult within 1 month",
        "recommendation": "Missing teeth detected. Consult a dentist about implants or dentures.",
    },
    "periapical": {
        "description": "A periapical lesion is an infection or abscess at the root tip of a tooth.",
        "symptoms": "Severe toothache, sensitivity, swelling, fever in some cases",
        "treatment": "Root canal treatment or extraction",
        "urgency": "URGENT - within 48 hours",
        "recommendation": "Periapical lesion detected. Root canal treatment may be required urgently.",
    },
    "impacted": {
        "description": "An impacted tooth cannot erupt properly due to lack of space.",
        "symptoms": "Pain, swelling, difficulty opening mouth",
        "treatment": "Surgical extraction by oral surgeon",
        "urgency": "Within 1 week",
        "recommendation": "Impacted tooth detected. Consult an oral surgeon for extraction evaluation.",
    },
    "bone loss": {
        "description": "Bone loss around teeth indicates advanced periodontal disease.",
        "symptoms": "Loose teeth, receding gums, bad breath",
        "treatment": "Periodontal therapy, possible surgery",
        "urgency": "URGENT - within 1 week",
        "recommendation": "Bone loss detected. Seek periodontal care immediately to prevent tooth loss.",
    },
    "fracture": {
        "description": "A tooth fracture is a crack or break in the tooth structure.",
        "symptoms": "Sharp pain when biting, sensitivity, visible crack",
        "treatment": "Bonding, crown, or extraction depending on severity",
        "urgency": "URGENT - within 48 hours",
        "recommendation": "Tooth fracture detected. Visit a dentist immediately for treatment.",
    },
    "cyst": {
        "description": "A dental cyst is a fluid-filled sac around tooth roots or impacted teeth.",
        "symptoms": "Swelling, pain, may be asymptomatic in early stages",
        "treatment": "Surgical removal",
        "urgency": "URGENT - within 1 week",
        "recommendation": "Cyst detected. Immediate dental evaluation and possible surgical removal required.",
    },
    "root resorption": {
        "description": "Root resorption is the loss of tooth root structure.",
        "symptoms": "May be asymptomatic, detected on X-ray",
        "treatment": "Root canal or extraction depending on severity",
        "urgency": "Within 1 week",
        "recommendation": "Root resorption detected. Consult a dentist immediately for evaluation.",
    },
    "attrition": {
        "description": "Attrition is the wearing down of tooth surfaces due to tooth-to-tooth contact.",
        "symptoms": "Flattened teeth, sensitivity, jaw pain",
        "treatment": "Night guard, dental restorations",
        "urgency": "Within 1 month",
        "recommendation": "Tooth attrition detected. Use a night guard and consult your dentist.",
    },
    "default": {
        "description": "Dental condition detected on scan.",
        "symptoms": "See a dentist for detailed evaluation",
        "treatment": "Professional dental consultation required",
        "urgency": "Within 1 month",
        "recommendation": "Consult a qualified dentist for proper diagnosis and treatment planning.",
    }
}

def _get_disease_info(disease: str) -> dict:
    d = disease.lower().replace(" ", "_")
    for key in DISEASE_INFO:
        if key in d or d in key:
            return DISEASE_INFO[key]
    return DISEASE_INFO["default"]

def _risk_level(confidence: float, disease: str) -> str:
    d = disease.lower()
    if any(x in d for x in ("cyst","abscess","cancer","periapical","bone loss","fracture")):
        return "High"
    if confidence >= 75 or any(x in d for x in ("impacted","root resorption","missing","malaligned","caries","ulcer")):
        return "Medium"
    return "Low"

def _prepare_image(raw: bytes) -> Image.Image:
    img = Image.open(io.BytesIO(raw)).convert("RGB")
    max_side = 1024
    if max(img.size) > max_side:
        img.thumbnail((max_side, max_side), Image.Resampling.LANCZOS)
    return img

def _image_to_base64(img: Image.Image) -> str:
    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=90)
    return base64.b64encode(buf.getvalue()).decode("utf-8")

# ROUTES

@router.get("/status")
async def model_status():
    if not MODELS_LOADED:
        return {"status": "error", "detail": MODEL_ERROR}
    return {"status": "ok", "device": str(device), "oral_labels": oral_labels}

@router.post("/xray")
async def predict_xray(file: UploadFile = File(...)):
    if not MODELS_LOADED:
        raise HTTPException(status_code=503, detail=MODEL_ERROR)
    try:
        raw = await file.read()
        img = _prepare_image(raw)

        valid, reason = _is_likely_xray_image(img)
        if not valid:
            raise HTTPException(status_code=400, detail=reason)

        results = yolo_xray(img, verbose=False)
        class_names = results[0].names
        disease = "Healthy"
        confidence = 85.0

        if results[0].boxes and len(results[0].boxes) > 0:
            best_box = max(results[0].boxes, key=lambda b_: float(b_.conf[0]))
            confidence = round(float(best_box.conf[0]) * 100, 2)
            class_id = int(best_box.cls[0])
            disease = class_names.get(class_id, f"Class_{class_id}")
        else:
            raise HTTPException(status_code=400,
                detail="No dental findings detected. Please upload a clear dental X-ray image.")

        info = _get_disease_info(disease)

        return {
            "disease": disease,
            "confidence": confidence,
            "affected_area": 0.0,
            "risk_level": _risk_level(confidence, disease),
            "description": info["description"],
            "symptoms": info["symptoms"],
            "treatment": info["treatment"],
            "urgency": info["urgency"],
            "recommendation": info["recommendation"],
            "image_width": int(img.width),
            "image_height": int(img.height),
            "bboxes": [],
            "annotated_image": _image_to_base64(img),
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=traceback.format_exc())

@router.post("/oral")
async def predict_oral(file: UploadFile = File(...)):
    if not MODELS_LOADED:
        raise HTTPException(status_code=503, detail=MODEL_ERROR)
    try:
        raw = await file.read()
        img = _prepare_image(raw)

        valid, reason = _is_likely_oral_image(img)
        if not valid:
            raise HTTPException(status_code=400, detail=reason)

        t = clf_tf(img).unsqueeze(0).to(device)
        with torch.no_grad():
            probs = torch.softmax(eff_oral(t), dim=1)[0]

        top1 = float(probs.max())
        top2 = float(probs.topk(2).values[1])
        if top1 < 0.45 or (top1 - top2) < 0.10:
            raise HTTPException(status_code=400,
                detail="Could not confidently identify an oral condition. Please upload a clearer intraoral photo.")

        idx = int(probs.argmax().item())
        confidence = round(top1 * 100, 2)
        disease = (oral_labels.get(str(idx), f"Class_{idx}")
                   if isinstance(oral_labels, dict) else oral_labels[idx])

        info = _get_disease_info(disease)

        return {
            "disease": disease,
            "confidence": confidence,
            "affected_area": 0.0,
            "risk_level": _risk_level(confidence, disease),
            "description": info["description"],
            "symptoms": info["symptoms"],
            "treatment": info["treatment"],
            "urgency": info["urgency"],
            "recommendation": info["recommendation"],
            "image_width": int(img.width),
            "image_height": int(img.height),
            "bboxes": [],
            "annotated_image": _image_to_base64(img),
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=traceback.format_exc())