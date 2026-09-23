import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/fitness/v1.dart' as fitness;
import 'package:http/http.dart' as http;

class _GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();

  _GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _client.send(request);
  }
}

class GoogleFitService extends ChangeNotifier {
  static final GoogleFitService _instance = GoogleFitService._internal();
  factory GoogleFitService() => _instance;
  GoogleFitService._internal();

  static const String _clientId = '993511560623-rplbmvi3n2u3nlhcg98qrcv4nrfria2.apps.googleusercontent.com';

  static const List<String> _scopes = [
    'https://www.googleapis.com/auth/fitness.activity.read',
    'https://www.googleapis.com/auth/fitness.location.read',
    'https://www.googleapis.com/auth/fitness.body.read',
  ];

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: _clientId,
    serverClientId: _clientId,
    scopes: _scopes,
  );

  bool _isConnected = false;
  bool _isChecking = false;
  bool _isFetchingData = false;
  int _todaySteps = 0;
  int _todayCalories = 0;
  double _todayDistanceKm = 0.0;
  String? _errorMessage;

  bool get isConnected => _isConnected;
  bool get isChecking => _isChecking;
  bool get isFetchingData => _isFetchingData;
  int get todaySteps => _todaySteps;
  int get todayCalories => _todayCalories;
  double get todayDistanceKm => _todayDistanceKm;
  String? get errorMessage => _errorMessage;

  int getTodaySteps() => _todaySteps;
  int getTodayCalories() => _todayCalories;
  double getTodayDistance() => _todayDistanceKm;

  /// Initialize and verify existing Google Fit authorization on app start / screen resume
  Future<void> initAndCheckState() async {
    if (_isChecking) return;
    _isChecking = true;
    _errorMessage = null;

    try {
      final bool isSignedIn = await _googleSignIn.isSignedIn();
      if (isSignedIn) {
        GoogleSignInAccount? account = _googleSignIn.currentUser;
        account ??= await _googleSignIn.signInSilently();

        if (account != null) {
          final bool canAccessScopes = await _googleSignIn.canAccessScopes(_scopes);
          if (canAccessScopes) {
            _isConnected = true;
            await _fetchTodayFitnessData(account);
          } else {
            _isConnected = false;
          }
        } else {
          _isConnected = false;
        }
      } else {
        _isConnected = false;
      }
    } catch (e) {
      debugPrint('GoogleFitService check error: $e');
      _isConnected = false;
    } finally {
      _isChecking = false;
      if (hasListeners) {
        notifyListeners();
      }
    }
  }

  Future<void> checkConnection() => initAndCheckState();

  /// Perform real Google Fit OAuth 2.0 Sign-In authorization flow
  Future<bool> connect() async {
    _isChecking = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 1. Trigger Google Sign-In OAuth popup/flow
      final GoogleSignInAccount? account = await _googleSignIn.signIn();

      if (account == null) {
        // User cancelled the Google account selection
        _isConnected = false;
        _errorMessage = 'Google Fit sign-in was cancelled.';
        _isChecking = false;
        notifyListeners();
        return false;
      }

      // 2. Request / verify fitness OAuth scopes
      bool hasScopes = await _googleSignIn.canAccessScopes(_scopes);
      if (!hasScopes) {
        hasScopes = await _googleSignIn.requestScopes(_scopes);
      }

      if (hasScopes) {
        _isConnected = true;
        await _fetchTodayFitnessData(account);
        _isChecking = false;
        notifyListeners();
        return true;
      } else {
        _isConnected = false;
        _errorMessage = 'Google Fit fitness scopes were not granted.';
        _isChecking = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('GoogleFitService connect error: $e');
      _isConnected = false;
      _errorMessage = 'Google Fit OAuth error: $e';
      _isChecking = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> requestPermissions() => connect();

  /// Disconnect / Revoke Google Fit access
  Future<void> disconnect() async {
    try {
      await _googleSignIn.disconnect();
    } catch (e) {
      await _googleSignIn.signOut();
    }
    _isConnected = false;
    _todaySteps = 0;
    _todayCalories = 0;
    _todayDistanceKm = 0.0;
    notifyListeners();
  }

  /// Fetch today's real fitness metrics (Steps, Calories, Distance) via Google Fit REST API
  Future<void> _fetchTodayFitnessData(GoogleSignInAccount account) async {
    _isFetchingData = true;
    notifyListeners();

    try {
      final authHeaders = await account.authHeaders;
      final authClient = _GoogleAuthClient(authHeaders);
      final fitnessApi = fitness.FitnessApi(authClient);

      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day, 0, 0, 0);

      final int startTimeMillis = midnight.millisecondsSinceEpoch;
      final int endTimeMillis = now.millisecondsSinceEpoch;

      final aggregateRequest = fitness.AggregateRequest(
        aggregateBy: [
          fitness.AggregateBy(dataTypeName: 'com.google.step_count.delta'),
          fitness.AggregateBy(dataTypeName: 'com.google.calories.expended'),
          fitness.AggregateBy(dataTypeName: 'com.google.distance.delta'),
        ],
        bucketByTime: fitness.BucketByTime(durationMillis: '${endTimeMillis - startTimeMillis}'),
        startTimeMillis: '$startTimeMillis',
        endTimeMillis: '$endTimeMillis',
      );

      final aggregateResponse = await fitnessApi.users.dataset.aggregate(
        aggregateRequest,
        'me',
      );

      int stepsSum = 0;
      double caloriesSum = 0.0;
      double distanceMetersSum = 0.0;

      if (aggregateResponse.bucket != null) {
        for (var bucket in aggregateResponse.bucket!) {
          if (bucket.dataset != null) {
            for (var dataset in bucket.dataset!) {
              if (dataset.point != null) {
                for (var point in dataset.point!) {
                  if (point.value != null) {
                    for (var val in point.value!) {
                      if (point.dataTypeName == 'com.google.step_count.delta') {
                        stepsSum += (val.intVal ?? val.fpVal?.toInt() ?? 0);
                      } else if (point.dataTypeName == 'com.google.calories.expended') {
                        caloriesSum += (val.fpVal ?? val.intVal?.toDouble() ?? 0.0);
                      } else if (point.dataTypeName == 'com.google.distance.delta') {
                        distanceMetersSum += (val.fpVal ?? val.intVal?.toDouble() ?? 0.0);
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }

      _todaySteps = stepsSum;
      _todayCalories = caloriesSum.round();
      _todayDistanceKm = distanceMetersSum / 1000.0;
    } catch (e) {
      debugPrint('GoogleFitService fetch data error: $e');
    } finally {
      _isFetchingData = false;
      notifyListeners();
    }
  }

  /// Refresh fitness metrics
  Future<void> refreshData() async {
    if (_isConnected) {
      final account = _googleSignIn.currentUser;
      if (account != null) {
        await _fetchTodayFitnessData(account);
      } else {
        await initAndCheckState();
      }
    } else {
      await initAndCheckState();
    }
  }
}
