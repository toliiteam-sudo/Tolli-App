import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// 🔑 TOLII GMAIL OAUTH2 REFRESH TOKEN GENERATOR
///
/// Usage:
///   dart run tools/get_refresh_token.dart <CLIENT_ID> <CLIENT_SECRET>
///
/// OR set environment variables before running:
///   set GMAIL_CLIENT_ID=your-client-id
///   set GMAIL_CLIENT_SECRET=your-client-secret
///   dart run tools/get_refresh_token.dart
///
/// ⚠️  NEVER hardcode secrets in this file. They are stored in:
///      Render Dashboard → Environment Variables (GMAIL_CLIENT_ID, GMAIL_CLIENT_SECRET)
///      Google Cloud Console → APIs & Services → Credentials
///
void main(List<String> args) async {
  final clientId = args.isNotEmpty
      ? args[0]
      : Platform.environment['GMAIL_CLIENT_ID'] ?? '';
  final clientSecret = args.length > 1
      ? args[1]
      : Platform.environment['GMAIL_CLIENT_SECRET'] ?? '';

  if (clientId.isEmpty || clientSecret.isEmpty) {
    print('');
    print('❌ ERROR: CLIENT_ID and CLIENT_SECRET are required.');
    print('');
    print('Usage:');
    print('  dart run tools/get_refresh_token.dart <CLIENT_ID> <CLIENT_SECRET>');
    print('');
    print('OR set env vars:');
    print('  \$env:GMAIL_CLIENT_ID="your-client-id"');
    print('  \$env:GMAIL_CLIENT_SECRET="your-client-secret"');
    print('  dart run tools/get_refresh_token.dart');
    print('');
    print('Find credentials at: https://console.cloud.google.com/apis/credentials');
    exit(1);
  }

  const port = 8989;
  final redirectUri = 'http://127.0.0.1:$port';

  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  print('\n=============================================================');
  print('🔑 TOLII GMAIL OAUTH2 REFRESH TOKEN GENERATOR');
  print('=============================================================\n');

  final query = Uri(
    scheme: 'https',
    host: 'accounts.google.com',
    path: '/o/oauth2/v2/auth',
    queryParameters: {
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'response_type': 'code',
      'scope': 'https://www.googleapis.com/auth/gmail.send',
      'access_type': 'offline',
      'prompt': 'consent',
    },
  );

  print('👉 STEP 1: Open this link in your browser:\n');
  print('${query.toString()}\n');
  print('👉 STEP 2: Sign in with the sender Google account (tolii.team@gmail.com) and click "Allow".');
  print('\nWaiting for authorization in browser...\n');

  await for (HttpRequest request in server) {
    final uri = request.uri;
    final code = uri.queryParameters['code'];
    final error = uri.queryParameters['error'];

    if (error != null) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..headers.contentType = ContentType.html
        ..write('<h3>Authorization Failed: $error</h3>');
      await request.response.close();
      print('❌ Authorization error from Google: $error');
      break;
    }

    if (code != null) {
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.html
        ..write('''
          <html>
          <body style="font-family: sans-serif; text-align: center; padding: 50px;">
            <h1 style="color: #10B981;">✅ Authorization Successful!</h1>
            <p>You can close this tab and return to your terminal / IDE.</p>
          </body>
          </html>
        ''');
      await request.response.close();

      print('Received authorization code! Exchanging for tokens with Google...');

      // Exchange code for refresh token
      final tokenRes = await http.post(
        Uri.parse('https://oauth2.googleapis.com/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'code': code,
          'client_id': clientId,
          'client_secret': clientSecret,
          'redirect_uri': redirectUri,
          'grant_type': 'authorization_code',
        },
      );

      print('Status: ${tokenRes.statusCode}');
      final data = jsonDecode(tokenRes.body);

      if (data['refresh_token'] != null) {
        print('\n=============================================================');
        print('🎉 SUCCESS! REFRESH TOKEN GENERATED:');
        print('=============================================================');
        print('\nGMAIL_REFRESH_TOKEN=${data['refresh_token']}\n');
        print('=============================================================\n');
      } else {
        print('❌ Failed to get refresh token: ${tokenRes.body}');
      }
      break;
    }
  }

  await server.close();
}
