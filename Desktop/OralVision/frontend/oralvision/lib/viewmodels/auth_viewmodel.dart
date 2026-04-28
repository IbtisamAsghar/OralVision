import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/auth_repository.dart';

// State definition for Auth
class AuthState {
  final bool isLoading;
  final String? error;
  final bool isAuthenticated;

  AuthState({this.isLoading = false, this.error, this.isAuthenticated = false});

  AuthState copyWith({bool? isLoading, String? error, bool? isAuthenticated}) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}

// Business Logic controller
class AuthViewModel extends Notifier<AuthState> {
  @override
  AuthState build() {
    final authRepo = ref.watch(authRepositoryProvider);
    
    // Listen to changes silently.
    authRepo.authStateChanges.listen((data) {
      final session = data.session;
      if (session != null) {
        state = state.copyWith(isAuthenticated: true, isLoading: false, error: null);
      } else {
        state = state.copyWith(isAuthenticated: false, isLoading: false);
      }
    });

    return AuthState(isAuthenticated: authRepo.currentUser != null);
  }

  Future<void> signIn(String email, String password) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await ref.read(authRepositoryProvider).signIn(email, password);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> signUpPatient({
    required String email,
    required String password,
    required String fullName,
    required int age,
    required String city,
    required String phone,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await ref.read(authRepositoryProvider).signUpPatient(
        email: email, password: password, fullName: fullName, age: age, city: city, phone: phone
      );
      // Wait for email confirmation mechanism handled natively
      state = state.copyWith(isLoading: false, error: "Success! Please safely check your email to verify your patient account.");
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> signUpDoctor({
    required String email,
    required String password,
    required String fullName,
    required int age,
    required String city,
    required String phone,
    required String licenseNumber,
    required int yearsOfExperience,
    required String specialization,
    required String clinicName,
    required String clinicAddress,
    required double consultationCharges,
    required String professionalBio,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await ref.read(authRepositoryProvider).signUpDoctor(
        email: email, password: password, fullName: fullName, age: age, city: city, phone: phone,
        licenseNumber: licenseNumber, yearsOfExperience: yearsOfExperience,
        specialization: specialization, clinicName: clinicName,
        clinicAddress: clinicAddress, consultationCharges: consultationCharges,
        professionalBio: professionalBio
      );
      state = state.copyWith(isLoading: false, error: "Success! Please safely check your email to verify your expert account.");
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
  }
}

final authViewModelProvider = NotifierProvider<AuthViewModel, AuthState>(() {
  return AuthViewModel();
});
