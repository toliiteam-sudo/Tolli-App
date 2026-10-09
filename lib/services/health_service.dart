import 'package:flutter/foundation.dart';
import 'package:health/health.dart';

enum HealthConnectionState {
  notConnected,
  connected,
  permissionRevoked,
  unavailable,
  needsUpdate,
}

class HealthService extends ChangeNotifier {
  static final HealthService _instance = HealthService._internal();
  factory HealthService() => _instance;
  HealthService._internal();

  final Health _health = Health();
  
  HealthConnectionState _state = HealthConnectionState.notConnected;
  int _todaySteps = 0;
  int _todayCalories = 0;
  double _todayDistanceKm = 0.0;
  
  bool _isChecking = false;
  bool _isFetchingData = false;
  String? _errorMessage;

  HealthConnectionState get state => _state;
  bool get isConnected => _state == HealthConnectionState.connected;
  int get todaySteps => _todaySteps;
  int get todayCalories => _todayCalories;
  double get todayDistanceKm => _todayDistanceKm;
  bool get isChecking => _isChecking;
  bool get isFetchingData => _isFetchingData;
  String? get errorMessage => _errorMessage;

  static const List<HealthDataType> _types = [
    HealthDataType.STEPS,
    HealthDataType.TOTAL_CALORIES_BURNED,
    HealthDataType.DISTANCE_DELTA,
  ];

  static const List<HealthDataAccess> _permissions = [
    HealthDataAccess.READ,
    HealthDataAccess.READ,
    HealthDataAccess.READ,
  ];

  int getTodaySteps() => _todaySteps;
  int getTodayCalories() => _todayCalories;
  double getTodayDistance() => _todayDistanceKm;

  /// Initialize and check Health Connect permissions state on app launch / screen entry
  Future<void> initAndCheckState() async {
    _isChecking = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _health.configure();

      final sdkStatus = await _health.getHealthConnectSdkStatus();

      if (sdkStatus == HealthConnectSdkStatus.sdkUnavailable) {
        _state = HealthConnectionState.unavailable;
        _isChecking = false;
        notifyListeners();
        return;
      }

      if (sdkStatus == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) {
        _state = HealthConnectionState.needsUpdate;
        _isChecking = false;
        notifyListeners();
        return;
      }

      // Check permissions for steps, calories, and distance
      bool? hasPermission = await _health.hasPermissions(
        _types,
        permissions: _permissions,
      );

      if (hasPermission == true) {
        _state = HealthConnectionState.connected;
        await _fetchTodayData();
      } else {
        if (_state == HealthConnectionState.connected) {
          _state = HealthConnectionState.permissionRevoked;
        } else {
          _state = HealthConnectionState.notConnected;
        }
      }
    } catch (e) {
      debugPrint('HealthService init error: $e');
      _errorMessage = 'Could not verify Health Connect status.';
      _state = HealthConnectionState.notConnected;
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }

  /// Alias for checkPermissions
  Future<void> checkPermissions() => initAndCheckState();

  /// Request permissions from the user
  Future<bool> connectHealth() async {
    _isChecking = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _health.configure();

      final sdkStatus = await _health.getHealthConnectSdkStatus();

      if (sdkStatus == HealthConnectSdkStatus.sdkUnavailable) {
        _state = HealthConnectionState.unavailable;
        _errorMessage = 'Health Connect is not available on this device.';
        _isChecking = false;
        notifyListeners();
        return false;
      }

      if (sdkStatus == HealthConnectSdkStatus.sdkUnavailableProviderUpdateRequired) {
        _state = HealthConnectionState.needsUpdate;
        _errorMessage = 'Health Connect needs to be installed or updated.';
        _isChecking = false;
        notifyListeners();
        await _health.installHealthConnect();
        return false;
      }

      // Request permission for steps, calories, and distance
      bool authorized = await _health.requestAuthorization(
        _types,
        permissions: _permissions,
      );

      if (authorized) {
        _state = HealthConnectionState.connected;
        await _fetchTodayData();
        _isChecking = false;
        notifyListeners();
        return true;
      } else {
        _state = HealthConnectionState.notConnected;
        _errorMessage = 'Health data access wasn\'t granted. You can connect it anytime from Settings.';
        _isChecking = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('HealthService connect error: $e');
      _errorMessage = 'An error occurred while connecting to Health Connect.';
      _state = HealthConnectionState.notConnected;
      _isChecking = false;
      notifyListeners();
      return false;
    }
  }

  /// Alias for requestPermissions
  Future<bool> requestPermissions() => connectHealth();

  /// Fetch steps, calories, and distance for today (midnight to now)
  Future<void> _fetchTodayData() async {
    _isFetchingData = true;
    notifyListeners();

    try {
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day, 0, 0, 0);

      // Fetch steps
      int? steps = await _health.getTotalStepsInInterval(midnight, now);
      _todaySteps = steps ?? 0;

      // Fetch raw data points for calories and distance
      List<HealthDataPoint> dataPoints = await _health.getHealthDataFromTypes(
        types: [
          HealthDataType.TOTAL_CALORIES_BURNED,
          HealthDataType.DISTANCE_DELTA,
        ],
        startTime: midnight,
        endTime: now,
      );

      double cals = 0.0;
      double distMeters = 0.0;

      for (var p in dataPoints) {
        final val = double.tryParse(p.value.toString()) ?? 0.0;
        if (p.type == HealthDataType.TOTAL_CALORIES_BURNED) {
          cals += val;
        } else if (p.type == HealthDataType.DISTANCE_DELTA) {
          distMeters += val;
        }
      }

      _todayCalories = cals.round();
      _todayDistanceKm = (distMeters / 1000.0);
    } catch (e) {
      debugPrint('Error fetching health data: $e');
    } finally {
      _isFetchingData = false;
      notifyListeners();
    }
  }

  /// Refresh step, calorie, and distance metrics
  Future<void> refreshData() async {
    if (_state == HealthConnectionState.connected) {
      await _fetchTodayData();
    } else {
      await initAndCheckState();
    }
  }

  /// Alias for refreshData
  Future<void> refreshSteps() => refreshData();

  /// Prompt install/update Health Connect
  Future<void> installHealthConnect() async {
    try {
      await _health.installHealthConnect();
    } catch (e) {
      debugPrint('Error installing Health Connect: $e');
    }
  }
}
