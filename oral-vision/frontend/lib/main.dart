import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'utils/colors.dart';
import 'utils/routes.dart';
import 'utils/page_transitions.dart';
import 'screens/patient_home_screen.dart';
import 'screens/patient_shell.dart';
import 'screens/dentist_shell.dart';
import 'screens/scan_screen.dart';
import 'screens/symptom_screen.dart';
import 'screens/chatbot_screen.dart';
import 'screens/history_screen.dart';
import 'screens/patient_profile_screen.dart';
import 'screens/dentist_profile_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/appointment_booking_screen.dart';
import 'screens/dentist_appointments_screen.dart';
import 'screens/find_dentist_screen.dart';
import 'screens/dentist_detail_screen.dart';
import 'screens/prescription_screen.dart';
import 'screens/patient_appointments_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://unrtxrkgopwmnxnuzzbj.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVucnR4cmtnb3B3bW54bnV6emJqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAxNDM0OTMsImV4cCI6MjA5NTcxOTQ5M30.WZtt2D69QQ_oVzkejhSWZemrgAL4y0-9Mxs2_E_5nNM',
  );
  runApp(const OralVisionApp());
}

class OralVisionApp extends StatelessWidget {
  const OralVisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: DeepLinkHandler(
        child: MaterialApp(
          title: 'OralVision',
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            primaryColor: AppColors.primary,
            scaffoldBackgroundColor: AppColors.background,
            colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
            fontFamily: 'Roboto',
          ),
          initialRoute: '/',
          routes: AppRoutes.routes,
          onGenerateRoute: (settings) {
            switch (settings.name) {
              // ── Shells (bottom nav containers) ──
              case '/patient-shell':
                return FadePageRoute(page: const PatientShell());
              case '/dentist-shell':
                return FadePageRoute(page: const DentistShell());

              // ── Patient screens ──
              case '/patient-home':
                return FadePageRoute(page: const PatientHomeScreen());
              case '/scan':
                return SlidePageRoute(page: const ScanScreen());
              case '/symptom':
                return SlidePageRoute(page: const SymptomScreen());
              case '/chatbot':
                return SlidePageRoute(page: const ChatbotScreen());
              case '/dentist-chatbot':
                return SlidePageRoute(page: const DentistChatbotScreen());
              case '/history':
                return SlidePageRoute(page: const HistoryScreen());
              case '/patient-profile':
                return SlidePageRoute(page: const PatientProfileScreen());
              case '/find-dentist':
                return SlidePageRoute(page: const FindDentistScreen());
              case '/dentist-detail':
                return SlidePageRoute(page: const DentistDetailScreen());
              case '/book-appointment':
                return SlidePageRoute(page: const AppointmentBookingScreen());
              case '/patient-appointments':
                return SlidePageRoute(page: const PatientAppointmentsScreen());

              // ── Dentist screens ──
              case '/dentist-dashboard':
                return FadePageRoute(page: const DentistShell());
              case '/dentist-profile':
                return SlidePageRoute(page: const DentistProfileScreen());
              case '/dentist-appointments':
                return SlidePageRoute(page: const DentistAppointmentsScreen());
              case '/prescription':
                return SlidePageRoute(page: const PrescriptionScreen());

              // ── Shared ──
              case '/forgot-password':
                return SlidePageRoute(page: const ForgotPasswordScreen());
              case '/reset-password':
                return SlidePageRoute(page: const ResetPasswordScreen());

              default:
                return null;
            }
          },
        ),
      ),
    );
  }
}

class DeepLinkHandler extends StatefulWidget {
  final Widget child;
  const DeepLinkHandler({super.key, required this.child});
  @override
  State<DeepLinkHandler> createState() => _DeepLinkHandlerState();
}

class _DeepLinkHandlerState extends State<DeepLinkHandler> {
  @override
  void initState() {
    super.initState();
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        navigatorKey.currentState?.pushNamedAndRemoveUntil('/reset-password', (_) => false);
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}