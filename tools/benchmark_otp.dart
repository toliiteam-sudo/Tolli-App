import 'dart:convert';
import 'package:http/http.dart' as http;

void main(List<String> args) async {
  print('====================================================');
  print('🚀 TOLII OTP SERVICE SPEED & HEALTH BENCHMARK');
  print('====================================================\n');

  final baseUrl = args.isNotEmpty ? args[0] : 'https://tolli-app.onrender.com';
  final testEmail = args.length > 1 ? args[1] : 'tolii.team@gmail.com';

  print('Target Host: $baseUrl');
  print('Test Recipient: $testEmail\n');

  // 1. Health check & Server Wakeup Latency
  print('1️⃣  Testing Server Ping / Wakeup Latency...');
  final pingStopwatch = Stopwatch()..start();
  try {
    final pingRes = await http.get(Uri.parse('$baseUrl/')).timeout(const Duration(seconds: 40));
    pingStopwatch.stop();
    print('   ✅ Server Ping: ${pingStopwatch.elapsedMilliseconds} ms (${(pingStopwatch.elapsedMilliseconds / 1000).toStringAsFixed(2)}s) [Status: ${pingRes.statusCode}]');
    print('   📊 Health Data: ${pingRes.body}');
  } catch (e) {
    pingStopwatch.stop();
    print('   ❌ Ping Failed: $e in ${pingStopwatch.elapsedMilliseconds} ms');
  }

  print('\n----------------------------------------------------');

  // 2. Request OTP & Measure Dispatch Time
  print('2️⃣  Dispatching OTP to: $testEmail...');
  final otpStopwatch = Stopwatch()..start();
  try {
    final otpRes = await http.post(
      Uri.parse('$baseUrl/api/request-otp'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': testEmail}),
    ).timeout(const Duration(seconds: 40));
    otpStopwatch.stop();

    print('   ⏱️  Total OTP Dispatch Time: ${otpStopwatch.elapsedMilliseconds} ms (${(otpStopwatch.elapsedMilliseconds / 1000).toStringAsFixed(2)} seconds)');
    print('   📩 Server Response: ${otpRes.body}');
  } catch (e) {
    otpStopwatch.stop();
    print('   ❌ OTP Request Failed: $e in ${otpStopwatch.elapsedMilliseconds} ms');
  }

  print('\n====================================================');
  print('🏁 BENCHMARK COMPLETE');
  print('====================================================\n');
}
