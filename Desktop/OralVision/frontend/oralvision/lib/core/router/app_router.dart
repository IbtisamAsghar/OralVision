final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  final authState = ref.watch(authViewModelProvider);
  final onboardingCompleted = ref.watch(onboardingProvider);

  return GoRouter(
    refreshListenable: notifier,
    initialLocation: '/onboarding',
    redirect: (context, state) {
      final isGoingToOnboarding = state.matchedLocation == '/onboarding';

      final isGoingToAuth = state.matchedLocation == '/login' ||
          state.matchedLocation == '/role-selection' ||
          state.matchedLocation == '/register/patient' ||
          state.matchedLocation == '/register/doctor';

      final isAuthenticated = authState.isAuthenticated;

      if (!onboardingCompleted) {
        if (!isGoingToOnboarding) return '/onboarding';
        return null;
      }

      if (isGoingToOnboarding && onboardingCompleted) {
        return isAuthenticated ? '/home' : '/login';
      }

      if (!isAuthenticated && !isGoingToAuth) {
        return '/login';
      }

      if (isAuthenticated && isGoingToAuth) {
        return '/home';
      }

      return null;
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
