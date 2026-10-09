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
  Future<void> warmUp();
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
  Future<void> warmUp() async {
    try {
      await http.get(Uri.parse('$baseUrl/')).timeout(const Duration(seconds: 5));
    } catch (_) {
      // Silent catch for background server wake-up ping
    }
  }

  @override
  Future<OtpResponse> requestOtp(String email) async {
    debugPrint('====================================================');
    debugPrint('[OTP REQUEST] 📤 Dispatching to: $email');
    debugPrint('[OTP REQUEST] URL: $baseUrl/api/request-otp');
    try {
      final stopwatch = Stopwatch()..start();
      final response = await http.post(
        Uri.parse('$baseUrl/api/request-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim()}),
      ).timeout(const Duration(seconds: 40));
      stopwatch.stop();

      debugPrint('[OTP REQUEST] 📥 Response Status: ${response.statusCode} in ${stopwatch.elapsedMilliseconds}ms');
      debugPrint('[OTP REQUEST] 📦 Response Body: ${response.body}');

      final Map<String, dynamic> data = jsonDecode(response.body);
      final isSuccess = data['success'] == true;
      if (isSuccess) {
        debugPrint('[OTP REQUEST] ✅ OTP successfully sent!');
      } else {
        debugPrint('[OTP REQUEST ERROR] ❌ Server returned failure: ${data['message']}');
      }

      return OtpResponse(
        success: isSuccess,
        message: data['message'] ?? (isSuccess ? 'OTP sent successfully' : 'Failed to send OTP'),
      );
    } on TimeoutException {
      debugPrint('[OTP REQUEST TIMEOUT] ⏱️ Server timeout after 40s');
      return OtpResponse(
        success: false,
        message: 'Server took too long to respond. Please try again.',
      );
    } catch (e, stack) {
      debugPrint('[OTP REQUEST EXCEPTION] 💥 Error sending OTP: $e');
      debugPrint('$stack');
      return OtpResponse(
        success: false,
        message: 'Could not connect to authentication server. Please check your internet connection.',
      );
    }
  }

  @override
  Future<OtpResponse> verifyOtp(String email, String otp) async {
    debugPrint('====================================================');
    debugPrint('[OTP VERIFY] 🔐 Verifying OTP for: $email, Code: $otp');
    debugPrint('[OTP VERIFY] URL: $baseUrl/api/verify-otp');
    try {
      final stopwatch = Stopwatch()..start();
      final response = await http.post(
        Uri.parse('$baseUrl/api/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim(),
          'otp': otp.trim(),
        }),
      ).timeout(const Duration(seconds: 30));
      stopwatch.stop();

      debugPrint('[OTP VERIFY] 📥 Response Status: ${response.statusCode} in ${stopwatch.elapsedMilliseconds}ms');
      debugPrint('[OTP VERIFY] 📦 Response Body: ${response.body}');

      final Map<String, dynamic> data = jsonDecode(response.body);
      final isSuccess = data['success'] == true;
      final firebaseToken = data['firebaseToken'] as String?;
      final uid = data['uid'] as String?;

      if (isSuccess) {
        debugPrint('[OTP VERIFY] ✅ OTP Code Validated!');
        if (firebaseToken != null && firebaseToken.isNotEmpty) {
          debugPrint('[OTP VERIFY] 🎟️ Firebase Custom Token received: ${firebaseToken.substring(0, 15)}... (UID: $uid)');
        } else {
          debugPrint('----------------------------------------------------');
          debugPrint('[OTP VERIFY WARNING] ⚠️ "firebaseToken" is NULL in response!');
          debugPrint('[OTP VERIFY WARNING] 💡 The Render server needs FIREBASE_SERVICE_ACCOUNT to generate login tokens.');
          debugPrint('----------------------------------------------------');
        }
      } else {
        debugPrint('[OTP VERIFY ERROR] ❌ Verification failed: ${data['message']}');
      }

      return OtpResponse(
        success: isSuccess,
        message: data['message'] ?? (isSuccess ? 'OTP verified' : 'Verification failed'),
        firebaseToken: firebaseToken,
        uid: uid,
      );
    } on TimeoutException {
      debugPrint('[OTP VERIFY TIMEOUT] ⏱️ Server timeout after 30s');
      return OtpResponse(
        success: false,
        message: 'Server took too long to respond. Please try again.',
      );
    } catch (e, stack) {
      debugPrint('[OTP VERIFY EXCEPTION] 💥 Error verifying OTP: $e');
      debugPrint('$stack');
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

  void warmUp() {
    _provider.warmUp();
  }

  Future<OtpResponse> requestOtp(String destination) {
    return _provider.requestOtp(destination);
  }

  Future<OtpResponse> verifyOtp(String destination, String otp) {
    return _provider.verifyOtp(destination, otp);
  }
}
