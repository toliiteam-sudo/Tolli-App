// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main(List<String> args) async {
  if (args.length < 2) {
    print('Usage: dart tools/get_refresh_token.dart <CLIENT_ID> <CLIENT_SECRET>');
    exit(1);
  }

  final clientId = args[0];
  final clientSecret = args[1];

  const port = 8080;
  final redirectUri = 'http://localhost:$port';

  HttpServer? server;
  try {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
  } catch (e) {
    print('❌ Could not bind to port $port: $e');
    exit(1);
  }

  final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
    'client_id': clientId,
    'redirect_uri': redirectUri,
    'response_type': 'code',
    'scope': 'https://www.googleapis.com/auth/gmail.send',
    'access_type': 'offline',
    'prompt': 'consent',
  });

  print('\n====================================================');
  print('🔑 TOLII AUTOMATIC GMAIL OAUTH TOKEN GENERATOR');
  print('====================================================\n');
  print('Listening on $redirectUri for Google callback...\n');
  print('👉 OPEN THIS URL IN YOUR BROWSER:\n');
  print(authUrl.toString());
  print('\n====================================================\n');

  try {
    Process.run('cmd', ['/c', 'start', authUrl.toString().replaceAll('&', '^&')]);
  } catch (_) {}

  await for (HttpRequest request in server) {
    final uri = request.uri;
    final code = uri.queryParameters['code'];
    final error = uri.queryParameters['error'];

    if (error != null) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..headers.contentType = ContentType.html
        ..write('<h1>Authentication Failed</h1><p>Google Error: $error</p>');
      await request.response.close();
      print('❌ Google Error: $error');
      await server.close();
      exit(1);
    }

    if (code != null) {
      print('Received authorization code from Google! Exchanging for token...');

      try {
        final tokenRes = await http.post(
          Uri.parse('https://oauth2.googleapis.com/token'),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {
            'client_id': clientId,
            'client_secret': clientSecret,
            'code': code,
            'grant_type': 'authorization_code',
            'redirect_uri': redirectUri,
          },
        );

        final data = jsonDecode(tokenRes.body);

        if (tokenRes.statusCode == 200 && data['refresh_token'] != null) {
          final refreshToken = data['refresh_token'];

          request.response
            ..statusCode = HttpStatus.ok
            ..headers.contentType = ContentType.html
            ..write('''
              <!DOCTYPE html>
              <html>
              <head><title>Success!</title></head>
              <body style="font-family: Arial, sans-serif; text-align: center; padding: 50px;">
                <h1 style="color: #10B981;">✅ Authorization Successful!</h1>
                <p style="font-size: 18px;">Your new Refresh Token has been generated.</p>
              </body>
              </html>
            ''');
          await request.response.close();

          print('\n====================================================');
          print('🎉 SUCCESS! GMAIL_REFRESH_TOKEN=' + refreshToken);
          print('====================================================\n');
        } else {
          request.response
            ..statusCode = HttpStatus.internalServerError
            ..headers.contentType = ContentType.html
            ..write('<h1>Token Exchange Failed</h1><pre>${tokenRes.body}</pre>');
          await request.response.close();
          print('❌ Token exchange failed: ' + tokenRes.body);
        }
      } catch (err) {
        print('❌ Exchange error: $err');
      }

      await server.close();
      break;
    }
  }
}
