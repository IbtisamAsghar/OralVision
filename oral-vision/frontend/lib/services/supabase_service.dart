import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final _supabase = Supabase.instance.client;

  Future<void> saveScanResult({
    required String disease,
    required double confidence,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    await _supabase.from('scan_history').insert({
      'user_id': user.id,
      'disease_detected': disease,
      'confidence_score': confidence,
    });
  }

  Future<void> saveSymptomResult({
    required Map<String, dynamic> symptoms,
    required String disease,
    required double confidence,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    await _supabase.from('symptom_history').insert({
      'user_id': user.id,
      'symptoms_input': symptoms,
      'predicted_disease': disease,
      'confidence_score': confidence,
    });
  }

  Future<List<Map<String, dynamic>>> getScanHistory() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];
    final data = await _supabase
        .from('scan_history')
        .select()
        .eq('user_id', user.id)
        .order('scanned_at', ascending: false);
    return List<Map<String, dynamic>>.from(data);
  }

  Future<String?> getUserRole() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    final profile = await _supabase
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .single();
    return profile['role'];
  }
}
