import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Provides the singleton Supabase client
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

// Provides the AuthRepository injecting the Supabase client
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

class AuthRepository {
  final SupabaseClient _supabase;
  AuthRepository(this._supabase);

  // Special SignUp binding Patient Schema JSON
  Future<AuthResponse> signUpPatient({
    required String email, 
    required String password,
    required String fullName,
    required int age,
    required String city,
    required String phone,
  }) async {
    return await _supabase.auth.signUp(
      email: email, 
      password: password,
      data: {
        'role': 'patient',
        'full_name': fullName,
        'age': age,
        'city': city,
        'phone_number': phone,
      }
    );
  }

  // Special SignUp binding Doctor Schema JSON
  Future<AuthResponse> signUpDoctor({
    required String email, 
    required String password,
    required String fullName,
    required int age,
    required String city,
    required String phone,
    required String licenseNumber,
    required int yearsOfExperience,
    required String specialization,
    required String professionalBio,
  }) async {
    return await _supabase.auth.signUp(
      email: email, 
      password: password,
      data: {
        'role': 'doctor',
        'full_name': fullName,
        'age': age,
        'city': city,
        'phone_number': phone,
        'license_number': licenseNumber,
        'years_of_experience': yearsOfExperience,
        'specialization': specialization,
        'professional_bio': professionalBio,
      }
    );
  }

  Future<AuthResponse> signIn(String email, String password) async {
    return await _supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  User? get currentUser => _supabase.auth.currentUser;
  
  // Exposes internal auth state changes stream for reactive VM listening
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;
}
