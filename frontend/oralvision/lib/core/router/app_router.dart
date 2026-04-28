import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../viewmodels/auth_viewmodel.dart';
import '../providers/preferences_provider.dart';

import '../../views/onboarding/onboarding_view.dart';
import '../../views/auth/role_selection_view.dart';
import '../../views/auth/patient_register_view.dart';
import '../../views/auth/doctor_register_view.dart';
import '../../views/auth/login_view.dart';
import '../../views/home/home_view.dart';

class RouterNotifier extends ChangeNotifier {
  final Ref ref;
  RouterNotifier(this.ref) {
    ref.listen(authViewModelProvider, (_, __) => notifyListeners());
    ref.listen(onboardingProvider, (_, __) => notifyListeners());
  }
}

final routerNotifierProvider = Provider((ref) => RouterNotifier(ref));

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    refreshListenable: notifier,
    initialLocation: '/onboarding',
    
    redirect: (context, state) {
      final authState = ref.read(authViewModelProvider);
      final onboardingCompleted = ref.read(onboardingProvider);

      final isGoingToOnboarding = state.matchedLocation == '/onboarding';
      final isGoingToAuth = state.matchedLocation == '/login' || 
                            state.matchedLocation == '/role-selection' || 
                            state.matchedLocation == '/register/patient' || 
                            state.matchedLocation == '/register/doctor';
      
      final isAuthenticated = authState.isAuthenticated;

      // 1. Barrier: Block any uninitiated users inside the Onboarding Module
      if (!onboardingCompleted) {
        if (!isGoingToOnboarding) return '/onboarding';
        return null; // let them stay on onboarding
      }

      // 2. Barrier: Push completed users directly past onboarding
      if (isGoingToOnboarding && onboardingCompleted) {
        return isAuthenticated ? '/home' : '/login';
      }

      // 3. Barrier: Absolute Security Check for Dashboard access
      if (!isAuthenticated && !isGoingToAuth) {
        return '/login';
      }

      // 4. Barrier: Session Bypass (Don't let logged-in users hit the login page again organically)
      if (isAuthenticated && isGoingToAuth) {
        return '/home';
      }

      return null; // Route is mathematically safe, allow navigation
    },

    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingView(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginView(),
      ),
      GoRoute(
        path: '/role-selection',
        builder: (context, state) => const RoleSelectionView(),
      ),
      GoRoute(
        path: '/register/patient',
        builder: (context, state) => const PatientRegisterView(),
      ),
      GoRoute(
        path: '/register/doctor',
        builder: (context, state) => const DoctorRegisterView(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomeView(),
      ),
    ],
  );
});
