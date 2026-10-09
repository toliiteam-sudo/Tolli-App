import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../controllers/auth_controller.dart';
import '../models/activity_model.dart';
import '../repositories/activity_repository.dart';

class ActivitiesController extends ChangeNotifier {
  static final ActivitiesController _instance = ActivitiesController._internal();
  factory ActivitiesController() => _instance;

  final ActivityRepository _activityRepository = ActivityRepository();
  StreamSubscription<List<ActivityModel>>? _activitiesSubscription;

  int _selectedDateIndex = 0;
  String _selectedFilterId = 'all';
  String _selectedLocation = 'Bhavnagar';

  int get selectedDateIndex => _selectedDateIndex;
  String get selectedFilterId => _selectedFilterId;
  String get selectedLocation => _selectedLocation;
  String get userName => AuthController.instance.state.displayName;

  late List<DateItemModel> _dates;
  late List<FilterChipModel> _filters;
  List<ActivityModel> _allActivities = [];
  List<ActivityModel> _userActivities = [];
  late List<PlayerModel> _quickInvites;

  final Set<String> _pendingRequestActivityIds = {};

  List<DateItemModel> get dates => _dates;
  List<FilterChipModel> get filters => _filters;
  List<ActivityModel> get userActivities => _userActivities;
  List<PlayerModel> get quickInvites => _quickInvites;

  bool isRequestPending(String activityId) => _pendingRequestActivityIds.contains(activityId);

  void addPendingRequest(String activityId) {
    _pendingRequestActivityIds.add(activityId);
    notifyListeners();
  }

  ActivitiesController._internal() {
    _initializeData();
    _startRealtimeSubscription();
    try {
      FirebaseAuth.instance.authStateChanges().listen((user) {
        _startRealtimeSubscription();
      });
    } catch (e) {
      debugPrint('FirebaseAuth authStateChanges omitted in non-Firebase test environment: $e');
    }
  }

  StreamSubscription<List<ActivityModel>>? _userActivitiesSubscription;

  void _startRealtimeSubscription() {
    _activitiesSubscription?.cancel();
    _userActivitiesSubscription?.cancel();
    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid;

      _activitiesSubscription = _activityRepository
          .watchActivities(currentUid: currentUid)
          .listen((firestoreActivities) {
        _allActivities = firestoreActivities;
        notifyListeners();
      }, onError: (error) {
        debugPrint('Error listening to real-time activities: $error');
      });

      if (currentUid != null && currentUid.isNotEmpty) {
        _userActivitiesSubscription = _activityRepository
            .watchUserUpcomingActivities(currentUid)
            .listen((upcoming) {
          _userActivities = upcoming;
          notifyListeners();
        }, onError: (error) {
          debugPrint('Error listening to user upcoming activities: $error');
        });
      } else {
        _userActivities = [];
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Firebase streams omitted in non-Firebase test environment: $e');
    }
  }

  void reset() {
    _selectedDateIndex = 0;
    _selectedFilterId = 'all';
    _initializeData();
    _startRealtimeSubscription();
    notifyListeners();
  }

  String _getShortDayName(int weekday) {
    const days = ['MON', 'TUE', 'WED', 'THU', 'FRI', 'SAT', 'SUN'];
    return days[(weekday - 1) % 7];
  }

  void _initializeData() {
    final now = DateTime.now();

    _dates = List.generate(180, (index) {
      final date = now.add(Duration(days: index));
      final dayName = index == 0 ? 'TODAY' : _getShortDayName(date.weekday);
      return DateItemModel(
        dayName: dayName,
        dayNumber: '${date.day}',
        date: date,
        isSelected: index == 0,
      );
    });

    _filters = [
      const FilterChipModel(
        id: 'all',
        label: 'All Activities',
        icon: Icons.explore_outlined,
        isSelected: true,
      ),
      const FilterChipModel(
        id: 'distance',
        label: 'Within 25 km',
        icon: Icons.location_on_outlined,
        isSelected: false,
      ),
      const FilterChipModel(
        id: 'time',
        label: 'Any time',
        icon: Icons.access_time_rounded,
        isSelected: false,
      ),
    ];

    _allActivities = [];
    _userActivities = [];
    _quickInvites = [];
  }

  List<ActivityModel> get activities {
    return _allActivities;
  }

  void selectDate(int index) {
    if (index < 0 || index >= _dates.length) return;
    _selectedDateIndex = index;
    for (int i = 0; i < _dates.length; i++) {
      _dates[i] = _dates[i].copyWith(isSelected: i == index);
    }
    notifyListeners();
  }

  void selectDateByDateTime(DateTime targetDate) {
    final index = _dates.indexWhere((d) =>
        d.date.year == targetDate.year &&
        d.date.month == targetDate.month &&
        d.date.day == targetDate.day);
    if (index != -1) {
      selectDate(index);
    } else {
      final dayName = _getShortDayName(targetDate.weekday);
      final newItem = DateItemModel(
        dayName: dayName,
        dayNumber: '${targetDate.day}',
        date: targetDate,
        isSelected: true,
      );
      _dates.add(newItem);
      _dates.sort((a, b) => a.date.compareTo(b.date));
      final newIndex = _dates.indexWhere((d) => d.date == targetDate);
      selectDate(newIndex != -1 ? newIndex : 0);
    }
  }

  void selectFilter(String filterId) {
    _selectedFilterId = filterId;
    for (int i = 0; i < _filters.length; i++) {
      _filters[i] = _filters[i].copyWith(isSelected: _filters[i].id == filterId);
    }
    notifyListeners();
  }

  void toggleFilter(String filterId) {
    final index = _filters.indexWhere((f) => f.id == filterId);
    if (index != -1) {
      final current = _filters[index].isSelected;
      _filters[index] = _filters[index].copyWith(isSelected: !current);
      if (!current) {
        _selectedFilterId = filterId;
      }
      notifyListeners();
    }
  }

  void updateLocation(String location) {
    _selectedLocation = location;
    notifyListeners();
  }

  void addActivity(ActivityModel activity) {
    final hostActivity = activity.copyWith(
      isHost: true,
      venueConfirmed: true,
    );
    _allActivities.insert(0, hostActivity);
    _userActivities.insert(0, hostActivity);
    notifyListeners();
  }

  Future<void> updateActivity(ActivityModel updatedActivity) async {
    await _activityRepository.updateActivity(updatedActivity);
    final allIndex = _allActivities.indexWhere((a) => a.id == updatedActivity.id);
    if (allIndex != -1) {
      _allActivities[allIndex] = updatedActivity;
    }
    final userIndex = _userActivities.indexWhere((a) => a.id == updatedActivity.id);
    if (userIndex != -1) {
      _userActivities[userIndex] = updatedActivity;
    }
    notifyListeners();
  }

  Future<void> deleteActivity(String activityId) async {
    await _activityRepository.deleteActivity(activityId);
    _allActivities.removeWhere((a) => a.id == activityId);
    _userActivities.removeWhere((a) => a.id == activityId);
    notifyListeners();
  }

  Future<void> removePlayerFromActivity(String activityId, String playerId) async {
    await _activityRepository.removeParticipant(activityId, playerId);
  }

  @override
  void dispose() {
    _activitiesSubscription?.cancel();
    super.dispose();
  }
}
