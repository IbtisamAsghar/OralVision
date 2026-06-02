import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dio/dio.dart';

class SymptomsState {
  final bool isLoading;
  final String? error;
  final Map<String, dynamic>? predictionResult;

  SymptomsState({this.isLoading = false, this.error, this.predictionResult});

  SymptomsState copyWith({
    bool? isLoading,
    String? error,
    Map<String, dynamic>? predictionResult,
  }) {
    return SymptomsState(
      isLoading: isLoading ?? this.isLoading,
      error: error,
      predictionResult: predictionResult ?? this.predictionResult,
    );
  }
}

class SymptomsViewModel extends Notifier<SymptomsState> {
  final Dio _dio = Dio();

  @override
  SymptomsState build() {
    return SymptomsState();
  }

  Future<void> runPrediction(Map<String, int> symptoms) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception("User not authenticated.");

      // For Android Emulator, localhost is 10.0.2.2.
      final baseUrl = dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:8000';

      final response = await _dio.post(
        '$baseUrl/predict/symptoms',
        data: {"patient_id": user.id, "symptoms": symptoms},
      );

      if (response.statusCode == 200 && response.data['status'] == 'success') {
        state = state.copyWith(
          isLoading: false,
          predictionResult: response.data['data'],
        );
      } else {
        throw Exception("Failed to get prediction from the AI server.");
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  void clearResult() {
    state = SymptomsState();
  }
}

final symptomsViewModelProvider =
    NotifierProvider<SymptomsViewModel, SymptomsState>(() {
      return SymptomsViewModel();
    });
