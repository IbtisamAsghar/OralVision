import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthProvider extends ChangeNotifier {
  final _supabase = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;
  String? _userRole;

  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get userRole => _userRole;

  bool get isLoggedIn => _supabase.auth.currentUser != null;

  Future<void> getUserRole() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final profile = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .single();

      _userRole = profile['role'];
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _supabase.auth.signOut();
    _userRole = null;
    notifyListeners();
  }

  /// Returns route after login: `/patient-shell` or `/dentist-shell`, or null on failure.
  Future<String?> routeAfterLogin({required String expectedRole}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    if (user.emailConfirmedAt == null) {
      await _supabase.auth.signOut();
      _error = 'Please confirm your email before logging in. Check your inbox.';
      notifyListeners();
      return null;
    }

    var profile = await _supabase
        .from('profiles')
        .select('role, full_name')
        .eq('id', user.id)
        .maybeSingle();

    if (profile == null) {
      final meta = user.userMetadata ?? {};
      final role = (meta['role'] ?? expectedRole).toString();
      try {
        await _supabase.from('profiles').upsert({
          'id': user.id,
          'email': user.email,
          'full_name': meta['full_name'] ?? '',
          'phone': meta['phone'] ?? '',
          'gender': meta['gender'] ?? 'male',
          'age': meta['age'] ?? 0,
          'role': role,
        });
        profile = {'role': role};
      } catch (e) {
        _error = 'Profile setup failed: $e';
        notifyListeners();
        return null;
      }
    }

    final role = profile['role']?.toString() ?? expectedRole;
    if (role != expectedRole) {
      await _supabase.auth.signOut();
      _error = expectedRole == 'patient'
          ? 'This account is registered as a dentist. Use dentist login.'
          : 'This account is registered as a patient. Use patient login.';
      notifyListeners();
      return null;
    }

    if (expectedRole == 'dentist') {
      final dentist = await _supabase
          .from('dentist_profiles')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();
      if (dentist == null) {
        await _supabase.auth.signOut();
        _error = 'No dentist profile found. Complete dentist registration first.';
        notifyListeners();
        return null;
      }
    }

    _userRole = role;
    notifyListeners();
    return expectedRole == 'dentist' ? '/dentist-shell' : '/patient-shell';
  }
}
