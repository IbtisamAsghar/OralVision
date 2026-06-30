# OralVision (FYP) — Project Structure

Share this folder with your partner. Edit files in the paths below.

## Repositories

| Folder | Purpose |
|--------|---------|
| `oral-vision/frontend/` | Flutter app (Android + iOS) |
| `oral-vision-backend/` | Live Python API (FastAPI, ML models) — deployed on Hugging Face |

> **Note:** `oral-vision/backend/` is an old copy. Use `oral-vision-backend/` for API changes.

---

## Frontend (`oral-vision/frontend/lib/`)

### Screens — UI pages
| File | What to change |
|------|----------------|
| `screens/splash_screen.dart` | App launch, session restore |
| `screens/role_selection_screen.dart` | Patient vs Dentist choice |
| `screens/patient_login_screen.dart` | Patient login (email + password) |
| `screens/patient_signup_screen.dart` | Patient registration |
| `screens/dentist_login_screen.dart` | Dentist login |
| `screens/dentist_signup_screen.dart` | Dentist registration |
| `screens/forgot_password_screen.dart` | Password reset email |
| `screens/patient_shell.dart` | Patient bottom navigation |
| `screens/patient_home_screen.dart` | Patient dashboard |
| `screens/scan_screen.dart` | AI scan + results + PDF |
| `screens/symptom_screen.dart` | Symptom checker (flashcards) |
| `screens/chatbot_screen.dart` | Patient + dentist chatbot |
| `screens/history_screen.dart` | Scan/symptom/prescription history |
| `screens/patient_appointments_screen.dart` | Patient appointments |
| `screens/appointment_booking_screen.dart` | Book appointment |
| `screens/find_dentist_screen.dart` | Find dentists |
| `screens/patient_profile_screen.dart` | Patient profile + logout |
| `screens/dentist_shell.dart` | Dentist bottom navigation |
| `screens/dentist_dashboard.dart` | Dentist dashboard |
| `screens/dentist_schedule_screen.dart` | Dentist schedule |
| `screens/dentist_patients_screen.dart` | Patient list |
| `screens/patient_detail_screen.dart` | Patient scans + prescriptions (dentist view) |
| `screens/prescription_screen.dart` | Write prescription |
| `screens/dentist_profile_screen.dart` | Dentist profile + logout |

### Services — API & business logic
| File | Purpose |
|------|---------|
| `services/api_service.dart` | Backend API calls (scan, symptom, chat) |
| `services/pdf_service.dart` | PDF reports (scan, prescription) |
| `services/supabase_service.dart` | Supabase helpers |

### Utils — Shared helpers
| File | Purpose |
|------|---------|
| `utils/routes.dart` | All app routes |
| `utils/navigation_utils.dart` | Logout + back-button fixes |
| `utils/colors.dart` | App theme colors |
| `utils/health_utils.dart` | Health score, risk labels |
| `utils/prescription_utils.dart` | Prescription data normalization |
| `utils/chat_formatter.dart` | Chatbot text formatting |
| `utils/appointment_utils.dart` | Time slots |

### Widgets — Reusable UI
| File | Purpose |
|------|---------|
| `widgets/scan_result_overlay.dart` | Affected-area grid + bbox overlay |
| `widgets/app_card.dart` | Card component |
| `widgets/circular_score.dart` | Health score ring |

### Config
| File | Purpose |
|------|---------|
| `main.dart` | App entry, Supabase init, routes |
| `providers/auth_provider.dart` | Login role checks, logout |

---

## Backend (`oral-vision-backend/`)

| File | Purpose |
|------|---------|
| `main.py` | FastAPI app entry |
| `routers/predict.py` | X-ray + oral image AI |
| `routers/symptom.py` | Symptom checker ML |
| `routers/chatbot.py` | Dental chatbot rules |
| `utils/model_loader.py` | Load PyTorch models |
| `models/` | Model weights + labels |

---

## Run locally

**Frontend:**
```bash
cd oral-vision/frontend
flutter pub get
flutter run
```

**Backend:**
```bash
cd oral-vision-backend
pip install -r requirements.txt
python main.py
```

---

## Common tasks

| Task | Edit these files |
|------|------------------|
| Change API URL | `services/api_service.dart` |
| Fix login/logout/back | `navigation_utils.dart`, `auth_provider.dart`, login screens |
| Improve scan report | `scan_screen.dart`, `pdf_service.dart`, `routers/predict.py` |
| Fix chatbot | `chatbot_screen.dart`, `routers/chatbot.py` |
| Fix prescriptions | `prescription_screen.dart`, `patient_detail_screen.dart`, `prescription_utils.dart` |
| Fix appointments | `appointment_booking_screen.dart`, `dentist_appointments_screen.dart` |
