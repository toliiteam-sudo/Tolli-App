import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class OtpResponse {
  final bool success;
  final String message;
  final String? firebaseToken;
  final String? uid;

  OtpResponse({
    required this.success,
    required this.message,
    this.firebaseToken,
    this.uid,
  });
}

abstract class BaseOtpProvider {
  Future<OtpResponse> requestOtp(String target);
  Future<OtpResponse> verifyOtp(String target, String otp);
}

class EmailOtpProvider implements BaseOtpProvider {
  // Live Render deployment URL
  static String baseUrl = 'https://tolli-app.onrender.com';

  static void setBaseUrl(String url) {
    baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  @override
  Future<OtpResponse> requestOtp(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/request-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim()}),
      ).timeout(const Duration(seconds: 15));

      final Map<String, dynamic> data = jsonDecode(response.body);
      return OtpResponse(
        success: data['success'] == true,
        message: data['message'] ?? (data['success'] == true ? 'OTP sent successfully' : 'Failed to send OTP'),
      );
    } on TimeoutException {
      return OtpResponse(
        success: false,
        message: 'Server took too long to respond. Please try again.',
      );
    } catch (e) {
      debugPrint('[OtpService] Error sending OTP request: $e');
      return OtpResponse(
        success: false,
        message: 'Could not connect to authentication server. Please check your internet connection.',
      );
    }
  }

  @override
  Future<OtpResponse> verifyOtp(String email, String otp) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim(),
          'otp': otp.trim(),
        }),
      ).timeout(const Duration(seconds: 15));

      final Map<String, dynamic> data = jsonDecode(response.body);
      return OtpResponse(
        success: data['success'] == true,
        message: data['message'] ?? (data['success'] == true ? 'OTP verified' : 'Verification failed'),
        firebaseToken: data['firebaseToken'] as String?,
        uid: data['uid'] as String?,
      );
    } on TimeoutException {
      return OtpResponse(
        success: false,
        message: 'Server took too long to respond. Please try again.',
      );
    } catch (e) {
      debugPrint('[OtpService] Error verifying OTP: $e');
      return OtpResponse(
        success: false,
        message: 'Verification connection failed. Please try again.',
      );
    }
  }
}

/// Central OTP Service with swappable providers (Email now, WhatsApp/AiSensy in future)
class OtpService {
  static final OtpService _instance = OtpService._internal();
  factory OtpService() => _instance;
  OtpService._internal();

  BaseOtpProvider _provider = EmailOtpProvider();

  void setProvider(BaseOtpProvider provider) {
    _provider = provider;
  }

  Future<OtpResponse> requestOtp(String destination) {
    return _provider.requestOtp(destination);
  }

  Future<OtpResponse> verifyOtp(String destination, String otp) {
    return _provider.verifyOtp(destination, otp);
  }
}
