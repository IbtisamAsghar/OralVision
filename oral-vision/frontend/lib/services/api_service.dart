import 'package:dio/dio.dart';
import 'dart:io';

class ApiService {
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 60),
    receiveTimeout: const Duration(seconds: 120),
    sendTimeout: const Duration(seconds: 60),
  ));

  static const String baseUrl =
      'https://moizpirzada1-oral-vision-backend.hf.space';

  Future<Map<String, dynamic>> predictXray(File imageFile) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(imageFile.path),
    });
    final response = await _dio.post(
      '$baseUrl/predict/xray',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return response.data;
  }

  Future<Map<String, dynamic>> predictOral(File imageFile) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(imageFile.path),
    });
    final response = await _dio.post(
      '$baseUrl/predict/oral',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return response.data;
  }

  Future<Map<String, dynamic>> checkSymptoms(
      Map<String, dynamic> data) async {
    final response = await _dio.post(
      '$baseUrl/symptom/',
      data: data,
      options: Options(contentType: 'application/json'),
    );
    return response.data;
  }

  Future<Map<String, dynamic>> sendChat(
      List<Map> messages, String userId) async {
    try {
      final response = await _dio.post(
        '$baseUrl/chatbot/',
        data: {'messages': messages, 'user_id': userId},
        options: Options(contentType: 'application/json'),
      );
      return Map<String, dynamic>.from(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 503) {
        await Future.delayed(const Duration(seconds: 3));
        final retry = await _dio.post(
          '$baseUrl/chatbot/',
          data: {'messages': messages, 'user_id': userId},
          options: Options(contentType: 'application/json'),
        );
        return Map<String, dynamic>.from(retry.data);
      }
      rethrow;
    }
  }
}