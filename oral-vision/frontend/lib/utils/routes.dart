import 'package:flutter/material.dart';
import '../screens/splash_screen.dart';
import '../screens/role_selection_screen.dart';
import '../screens/patient_login_screen.dart';
import '../screens/patient_signup_screen.dart';
import '../screens/patient_home_screen.dart';
import '../screens/dentist_login_screen.dart';
import '../screens/dentist_signup_screen.dart';
import '../screens/dentist_dashboard.dart';
import '../screens/scan_screen.dart';
import '../screens/result_screen.dart';
import '../screens/symptom_screen.dart';
import '../screens/chatbot_screen.dart';
import '../screens/history_screen.dart';
import '../screens/patient_profile_screen.dart';
import '../screens/dentist_profile_screen.dart';
import '../screens/forgot_password_screen.dart';
import '../screens/reset_password_screen.dart';
import '../screens/appointment_booking_screen.dart';
import '../screens/dentist_appointments_screen.dart';
import '../screens/find_dentist_screen.dart';
import '../screens/dentist_detail_screen.dart';
import '../screens/prescription_screen.dart';
import '../screens/patient_appointments_screen.dart';
import '../screens/patient_detail_screen.dart';
import '../screens/patient_shell.dart';
import '../screens/dentist_shell.dart';
class AppRoutes {
  static Map<String, WidgetBuilder> get routes => {
        '/': (ctx) => const SplashScreen(),
        '/role': (ctx) => const RoleSelectionScreen(),
        '/patient-login': (ctx) => const PatientLoginScreen(),
        '/patient-signup': (ctx) => const PatientSignupScreen(),
        '/patient-home': (ctx) => const PatientHomeScreen(),
        '/patient-shell': (ctx) => const PatientShell(),
        '/dentist-login': (ctx) => const DentistLoginScreen(),
        '/dentist-signup': (ctx) => const DentistSignupScreen(),
        '/dentist-dashboard': (ctx) => const DentistShell(),
        '/dentist-shell': (ctx) => const DentistShell(),
        '/scan': (ctx) => const ScanScreen(),
        '/result': (ctx) => const ResultScreen(),
        '/symptom': (ctx) => const SymptomScreen(),
        '/symptom-checker': (ctx) => const SymptomScreen(),
        '/chatbot': (ctx) => const ChatbotScreen(),
        '/dentist-chatbot': (ctx) => const DentistChatbotScreen(),
        '/history': (ctx) => const HistoryScreen(),
        '/patient-profile': (ctx) => const PatientProfileScreen(),
        '/dentist-profile': (ctx) => const DentistProfileScreen(),
        '/forgot-password': (ctx) => const ForgotPasswordScreen(),
        '/reset-password': (ctx) => const ResetPasswordScreen(),
        '/book-appointment': (ctx) => const AppointmentBookingScreen(),
        '/dentist-appointments': (ctx) => const DentistAppointmentsScreen(),
        '/patient-appointments': (ctx) => const PatientAppointmentsScreen(),
        '/find-dentist': (ctx) => const FindDentistScreen(),
        '/dentist-detail': (ctx) => const DentistDetailScreen(),
        '/prescription': (ctx) => const PrescriptionScreen(),
        '/patient-detail': (ctx) {
          final patientId =
              ModalRoute.of(ctx)!.settings.arguments as String;
          return PatientDetailScreen(patientId: patientId);
        },
      };
}