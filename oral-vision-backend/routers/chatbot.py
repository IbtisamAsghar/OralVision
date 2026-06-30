from fastapi import APIRouter
from pydantic import BaseModel
from typing import List
import re

router = APIRouter()

class Message(BaseModel):
    role: str
    content: str

class ChatInput(BaseModel):
    messages: List[Message]
    user_id: str

RULES = [
    (["hello", "hi", "hey", "salam", "assalam"],
     "Hello! I'm OralVision AI, your dental health assistant. You can ask me about tooth pain, cavities, gum problems, braces, root canals, whitening, and much more!"),
    (["how are you", "how r you", "you ok"],
     "I'm doing great, thank you for asking! I'm here to help with all your dental health questions. What's on your mind?"),
    (["what can you do", "help", "what do you know", "capabilities"],
     "I can help you with:\n- Tooth pain & sensitivity\n- Cavities & fillings\n- Gum disease & bleeding\n- Root canals\n- Teeth whitening\n- Braces & aligners\n- Bad breath\n- Wisdom teeth\n- Children's dental health\n- General oral hygiene tips\n\nJust ask me anything!"),
    (["tooth pain", "toothache", "teeth pain", "tooth ache", "my tooth hurts", "teeth hurt", "pain in tooth", "pain in teeth"],
     "Tooth pain can have several causes:\n\n- Cavity - decay reaching the nerve\n- Cracked tooth - pain when biting\n- Abscess - infection causing throbbing pain\n- Gum disease - pain near gum line\n- Sensitivity - sharp pain with hot/cold\n\nIf pain is severe or has lasted more than 2 days, please visit a dentist immediately. In the meantime, you can take over-the-counter pain relief like ibuprofen."),
    (["sharp pain", "sudden pain", "pain when biting", "pain when chewing", "hurts to chew", "hurts to bite"],
     "Sharp pain when biting or chewing usually indicates:\n\n- A cracked tooth\n- A loose filling\n- Decay that has reached the inner pulp\n\nPlease see a dentist soon - a cracked tooth can worsen quickly if left untreated."),
    (["throbbing pain", "severe pain", "unbearable pain", "extreme pain"],
     "Throbbing or severe tooth pain is often a sign of a dental abscess (infection). This is urgent!\n\nPlease visit a dentist or emergency dental clinic as soon as possible. Do not ignore this - dental infections can spread if untreated.\n\nYou can take ibuprofen for temporary pain relief while arranging your appointment."),
    (["sensitivity", "sensitive teeth", "sensitive tooth", "hurt with cold", "hurt with hot", "cold hurts", "hot hurts", "pain with sweet", "sweet hurts"],
     "Tooth sensitivity is very common. It happens when the protective enamel wears down, exposing the dentine underneath.\n\nTips to manage sensitivity:\n- Use a sensitivity toothpaste (e.g. Sensodyne)\n- Avoid very hot, cold, or sweet foods/drinks\n- Use a soft-bristle toothbrush\n- Avoid brushing too hard\n\nIf sensitivity is severe or getting worse, your dentist may recommend fluoride treatment, bonding agent on exposed roots, or a gum graft if recession is the cause."),
    (["cavity", "cavities", "tooth decay", "decayed tooth", "hole in tooth", "black spot on tooth", "decay"],
     "A cavity is a permanently damaged area in the hard surface of your tooth caused by bacteria.\n\nSigns: toothache or sensitivity, visible holes or pits, brown/black/white staining, pain when eating sweet/hot/cold foods.\n\nTreatment: small cavity needs a filling, large cavity needs a crown or inlay, very deep needs a root canal.\n\nPrevention: brush twice daily with fluoride toothpaste, floss daily, reduce sugary food, visit dentist every 6 months."),
    (["filling", "tooth filling", "composite filling", "amalgam filling"],
     "A dental filling is the most common treatment for cavities.\n\nTypes: Composite (tooth-coloured, most popular), Amalgam (silver, very durable), Glass ionomer (releases fluoride, good for children).\n\nThe procedure: dentist numbs the area, removes decayed tissue, fills and shapes the tooth, polishes it. Fillings usually last 5-15 years depending on material and care."),
    (["bleeding gums", "gums bleed", "gum bleeding", "blood from gums", "gums bleed when i brush"],
     "Bleeding gums are one of the most common signs of gingivitis (early gum disease).\n\nCommon causes: poor oral hygiene, brushing too hard, vitamin deficiency, hormonal changes, blood thinners.\n\nWhat to do: brush gently twice daily with a soft brush, floss daily, use antibacterial mouthwash, see your dentist for a professional clean. If bleeding is heavy or doesn't improve in 2 weeks, please see a dentist."),
    (["gum disease", "gingivitis", "periodontitis", "gum infection", "gum problem", "swollen gums", "gums swollen", "inflamed gums"],
     "Gum disease is an infection of the tissues holding your teeth in place.\n\nStages: Gingivitis (early, reversible) and Periodontitis (advanced, can cause tooth loss).\n\nSymptoms: red/swollen/tender gums, bleeding when brushing, persistent bad breath, receding gums, loose teeth.\n\nTreatment: professional cleaning, deep cleaning (root planing), antibiotics in severe cases, surgery for advanced cases. Early treatment is key."),
    (["receding gums", "gum recession", "gums pulling back", "tooth root exposed"],
     "Gum recession means your gum tissue is pulling back, exposing more of your tooth or root.\n\nCauses: brushing too hard, gum disease, teeth grinding, genetics.\n\nTreatment: improved brushing technique, scaling and root planing, gum graft surgery for severe cases. See your dentist to assess progression."),
    (["root canal", "root canal treatment", "rct", "nerve removal", "pulp removal"],
     "A root canal is a procedure to save a severely infected or damaged tooth.\n\nNeeded when: deep cavity reaching the pulp, cracked tooth with infected nerve, repeated procedures on same tooth, trauma.\n\nProcedure (1-2 visits): X-ray, local anaesthesia, pulp removal, canal cleaning, filling with gutta-percha, crown placement. With modern anaesthesia, root canals are no more painful than a regular filling."),
    (["tooth extraction", "pull tooth", "remove tooth", "tooth removal", "extract tooth"],
     "Tooth extraction is sometimes necessary when a tooth cannot be saved.\n\nReasons: severe decay/infection, crowding for orthodontics, wisdom tooth problems, broken tooth below gum line.\n\nAftercare: bite on gauze 30-45 min, no rinsing for 24h, no smoking/straws, soft foods 24-48h, prescribed painkillers, ice pack for swelling. Contact your dentist if heavy bleeding, severe pain after 3 days, or fever."),
    (["wisdom tooth", "wisdom teeth", "third molar", "back tooth pain", "last tooth"],
     "Wisdom teeth are the last molars to come in, usually between ages 17-25.\n\nCommon problems: impaction, crowding, infection (pericoronitis), cavities, cysts.\n\nSigns: pain at back of mouth, swollen/red gum at back, jaw stiffness, bad taste or smell.\n\nTreatment: extraction if causing problems, or leave in place if healthy and properly positioned. An X-ray is needed to assess properly."),
    (["bad breath", "halitosis", "smell from mouth", "mouth smell", "breath smell", "smelly breath", "my breath smells"],
     "Bad breath (halitosis) is very common and usually treatable.\n\nCauses: poor oral hygiene, food, dry mouth, gum disease, tooth decay, smoking, stomach issues.\n\nTips: brush teeth and tongue twice daily, floss daily, stay hydrated, use antibacterial mouthwash, chew sugar-free gum, quit smoking, regular dental checkups. If it persists despite good hygiene, see your dentist."),
    (["whitening", "white teeth", "teeth whitening", "yellow teeth", "teeth yellow", "stained teeth", "teeth stain", "brighten teeth"],
     "Teeth whitening is one of the most popular cosmetic dental treatments.\n\nOptions: professional whitening (fastest, safest), at-home trays (dentist-prescribed), whitening toothpaste (surface stains only), over-the-counter strips (mild effect).\n\nCauses of yellow teeth: coffee/tea/wine, smoking, aging, certain medications, poor hygiene. Whitening does not work on crowns, veneers, or fillings. Consult your dentist before starting."),
    (["braces", "orthodontics", "orthodontist", "crooked teeth", "misaligned teeth", "teeth alignment", "aligner", "invisalign"],
     "Orthodontic treatment straightens teeth and improves your bite.\n\nTypes: metal braces (most common), ceramic braces (less visible), lingual braces (behind teeth), clear aligners/Invisalign (removable).\n\nDuration: mild 6-12 months, moderate 12-18 months, severe 18-36 months. Best results when started young (10-14), but adults can also get braces. A retainer after treatment is essential."),
    (["swelling", "swollen face", "face swollen", "jaw swollen", "swollen jaw", "cheek swollen", "facial swelling"],
     "Facial or jaw swelling related to a tooth is often a sign of a dental abscess - a serious infection. This requires urgent attention!\n\nPlease see a dentist or go to an emergency clinic today. If you have difficulty breathing or swallowing, go to the emergency room immediately."),
    (["child teeth", "baby teeth", "children teeth", "kids teeth", "milk teeth", "my child", "my kid", "toddler teeth"],
     "Children's dental health is so important!\n\nMilestones: first tooth around 6 months, full set of baby teeth by age 3, baby teeth fall out ages 6-12, adult teeth complete by age 13.\n\nTips: start brushing as soon as first tooth appears, use fluoride toothpaste from age 3, limit sugary drinks/snacks, first dentist visit by age 1, avoid bottle at bedtime, dental sealants protect molars."),
    (["dentures", "false teeth", "dental plate", "full denture", "partial denture"],
     "Dentures are removable replacements for missing teeth.\n\nTypes: full dentures (replace all teeth), partial dentures (replace some), implant-supported dentures (more stable).\n\nCare: remove and rinse after eating, brush daily with soft brush, soak overnight in denture solution, handle carefully, see dentist regularly for adjustments."),
    (["implant", "dental implant", "tooth implant", "missing tooth", "missing teeth", "replace tooth"],
     "Dental implants are the gold standard for replacing missing teeth.\n\nA titanium post surgically placed in the jawbone acts as an artificial tooth root.\n\nProcess: consultation/scan, implant placement surgery, healing 3-6 months, abutment placement, crown attachment.\n\nBenefits: looks/feels natural, prevents bone loss, lasts 20+ years. Not suitable with active gum disease, insufficient bone, or uncontrolled diabetes."),
    (["brush", "brushing", "how to brush", "brushing technique", "when to brush"],
     "Proper brushing technique is the foundation of good oral health!\n\nHow: use soft-bristle brush, pea-sized fluoride toothpaste, hold at 45 degree angle, gentle circular motions, brush all surfaces and tongue, brush for 2 minutes, replace brush every 3 months.\n\nWhen: morning after breakfast and before bed. Wait 30 minutes after acidic foods before brushing."),
    (["floss", "flossing", "how to floss", "should i floss"],
     "Flossing removes plaque and food from between teeth where your brush can't reach.\n\nHow: use about 45cm of floss, wind around middle fingers, guide between teeth with gentle sawing motion, curve around each tooth in a C-shape.\n\nWhen: once daily, ideally before bed. Alternatives: interdental brushes, water flosser, floss picks. Bleeding usually stops within 1-2 weeks of consistent flossing."),
    (["mouthwash", "mouth rinse", "which mouthwash", "should i use mouthwash"],
     "Mouthwash is a great addition to your oral hygiene routine but not a replacement for brushing and flossing.\n\nTypes: antibacterial, fluoride, whitening, alcohol-free.\n\nHow to use: after brushing and flossing, rinse 30-60 seconds, don't eat/drink for 30 minutes after. Don't use immediately after brushing - wait 30 minutes so fluoride from toothpaste isn't washed away."),
    (["sugar", "diet", "food for teeth", "what to eat", "what to avoid", "good food for teeth"],
     "Your diet plays a huge role in your dental health!\n\nGood foods: dairy, leafy greens, crunchy vegetables, water, nuts.\n\nLimit: sugary snacks, fizzy drinks, fruit juice, sticky foods, coffee/tea, alcohol.\n\nTip: if you eat sugary food, have it with a meal rather than as a snack, and rinse with water afterwards."),
    (["grinding", "bruxism", "grind teeth", "clenching", "clench teeth", "teeth grinding at night", "jaw clenching"],
     "Teeth grinding (bruxism) often happens during sleep.\n\nSigns: worn down teeth, jaw pain/stiffness in morning, headaches, sensitivity, partner hears grinding.\n\nCauses: stress, sleep disorders, misaligned bite, medications.\n\nTreatment: custom night guard, stress management, avoid caffeine/alcohol before bed, jaw physiotherapy."),
    (["dry mouth", "mouth dry", "not enough saliva", "xerostomia"],
     "Dry mouth (xerostomia) occurs when salivary glands don't produce enough saliva.\n\nSaliva neutralises acids and helps prevent decay, so dry mouth increases cavity risk.\n\nCauses: medications, dehydration, mouth breathing, diabetes.\n\nTips: drink water frequently, chew sugar-free gum, use alcohol-free mouthwash, use a humidifier at night."),
    (["appointment", "book dentist", "see dentist", "visit dentist", "dentist appointment", "how often dentist"],
     "Regular dental visits are essential for maintaining good oral health!\n\nFrequency: every 6 months routine, every 3-4 months with gum disease, every 12 months if very healthy.\n\nAt a checkup: examination, X-rays (yearly), professional cleaning, oral cancer screening. You can use the OralVision app to find a dentist near you and book an appointment!"),
    (["oral vision", "oralvision", "this app", "app feature", "what is this app"],
     "OralVision is an AI-powered oral health app designed to help you monitor and improve your dental health!\n\nFeatures: AI Scan for instant disease detection, Symptom Checker, Prescriptions, Appointments, Find Dentist, Health Score tracking, and this AI Chatbot.\n\nOralVision is a support tool - always consult a qualified dentist for diagnosis and treatment."),
    (["pregnancy", "pregnant", "dental during pregnancy", "teeth during pregnancy"],
     "Dental health during pregnancy is very important!\n\nHormonal changes increase gum disease risk, morning sickness acid can erode enamel, calcium demands increase.\n\nSafe during pregnancy: routine checkups, urgent X-rays with lead apron, local anaesthesia, most fillings.\n\nTips: rinse after vomiting, eat calcium-rich foods, tell your dentist you're pregnant, best time for non-urgent work is second trimester."),
    (["smoking", "smoker teeth", "tobacco", "cigarette teeth", "vaping teeth"],
     "Smoking and tobacco use are among the most harmful things for your oral health.\n\nEffects: staining, bad breath, 3x higher gum disease risk, delayed healing, reduced taste/smell, increased oral cancer risk, tooth loss.\n\nVaping also causes gum inflammation and dry mouth.\n\nQuitting has immediate benefits - gum health improves within weeks."),
    (["thank you", "thanks", "thank u", "shukriya", "jazakallah", "bye", "goodbye", "see you"],
     "You're welcome! Remember, good oral health is key to your overall wellbeing. Don't hesitate to come back if you have more questions. Take care of your smile!"),
]

def get_response(message: str) -> str:
    message = message.lower().strip()
    for keywords, response in RULES:
        for keyword in keywords:
            if keyword in message:
                return response
    return (
        "I'm not sure I understood that. Here are some topics I can help with:\n\n"
        "- Tooth pain or sensitivity\n- Cavities and fillings\n- Bleeding or swollen gums\n"
        "- Root canal treatment\n- Teeth whitening\n- Braces and aligners\n- Bad breath\n"
        "- Wisdom teeth\n- Oral hygiene tips\n- Dental appointments\n\n"
        "Please try asking about one of these topics!"
    )

CLINICAL_RULES = [
    (["treatment", "protocol", "procedure"],
     "For cavity treatment: 1) Local anesthesia 2) Caries removal 3) Composite/amalgam restoration. For severe cases consider pulpotomy or extraction."),
    (["prescription", "medicine", "drug", "antibiotic"],
     "Common dental prescriptions:\n- Amoxicillin 500mg TID x 5 days (infection)\n- Metronidazole 400mg TID (anaerobic)\n- Ibuprofen 400mg TDS (pain)\n- Chlorhexidine 0.2% mouthwash BID"),
    (["triage", "urgent", "emergency"],
     "Dental emergency triage:\nIMMEDIATE: Facial swelling/airway compromise, uncontrolled bleeding\nURGENT: Acute abscess, severe pain, trauma\nROUTINE: Cavities, routine extractions, cosmetic"),
    (["abscess", "infection", "swelling"],
     "Abscess management:\n1. Drainage (I&D if fluctuant)\n2. Amoxicillin 500mg + Metronidazole 400mg\n3. Analgesics\n4. Follow-up in 48-72h\n5. Definitive treatment after acute phase"),
    (["root canal", "endo", "pulp"],
     "RCT steps:\n1. Access cavity preparation\n2. Working length determination (apex locator + X-ray)\n3. Biomechanical preparation\n4. Irrigation (NaOCl 2.5%)\n5. Obturation with gutta-percha\n6. Coronal seal + crown"),
    (["extraction", "exo", "remove tooth"],
     "Extraction protocol:\n1. Assess medical history\n2. LA: Inferior alveolar block / infiltration\n3. Luxation then extraction\n4. Socket curettage\n5. Post-op: gauze 30min, antibiotics if indicated, analgesics"),
    (["xray", "radiograph", "imaging"],
     "Radiographic guidelines:\n- Periapical: caries, periapical pathology, RCT\n- Bitewing: interproximal caries, bone level\n- OPG: full mouth survey, wisdom teeth, TMJ\n- CBCT: implant planning, complex anatomy"),
    (["implant", "implants"],
     "Implant considerations:\n- Adequate bone volume (min 1mm around implant)\n- No active infection or periodontitis\n- Controlled systemic conditions\n- Healing: 3-6 months osseointegration\n- Contraindications: bisphosphonates, radiation, uncontrolled DM"),
    (["pediatric", "child", "kids", "baby"],
     "Pediatric dentistry notes:\n- Primary teeth important for space maintenance\n- Pulpotomy preferred over extraction when possible\n- Fluoride varnish 2-4x/year for high-risk\n- Space maintainer after premature primary loss"),
    (["gum", "perio", "periodont"],
     "Periodontal treatment:\n- Gingivitis: OHI + scaling\n- Mild periodontitis: SRP (deep scaling)\n- Moderate-severe: SRP + systemic antibiotics\n- Surgical: flap surgery if >5mm pockets persist"),
    (["hello", "hi", "hey"],
     "Hello Doctor! I'm your OralVision Clinical Assistant. I can help with treatment protocols, drug prescriptions, emergency triage, diagnostic guidance, and radiographic interpretation. What clinical question can I assist with?"),
]

def get_clinical_response(message: str) -> str:
    message = message.lower().strip()
    for keywords, response in CLINICAL_RULES:
        for keyword in keywords:
            if keyword in message:
                return response
    return ("I can assist with clinical protocols, prescriptions, triage, and dental procedures. "
            "Please ask about a specific condition or treatment - e.g., 'root canal protocol', "
            "'antibiotic prescription for abscess', or 'extraction procedure'.")

@router.post("/")
async def chat(data: ChatInput):
    if not data.messages:
        return {
            "role": "assistant",
            "content": "Hello! I'm OralVision AI assistant. How can I help you with your dental health today?"
        }

    last_message = data.messages[-1].content

    if last_message.lower().startswith("clinical:"):
        clinical_msg = last_message[9:].strip()
        response_text = get_clinical_response(clinical_msg)
        return {"role": "assistant", "content": response_text}

    response_text = get_response(last_message)
    return {"role": "assistant", "content": response_text}
