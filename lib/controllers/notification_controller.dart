import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';

class NotificationController extends ChangeNotifier {
  static final NotificationController _instance = NotificationController._internal();
  factory NotificationController() => _instance;
  static NotificationController get instance => _instance;

  final NotificationRepository _repository = NotificationRepository();

  StreamSubscription<List<NotificationModel>>? _notificationsSubscription;
  StreamSubscription<User?>? _authSubscription;

  List<NotificationModel> _notifications = [];
  int _unreadCount = 0;

  List<NotificationModel> get notifications => _notifications;
  int get unreadCount => _unreadCount;
  bool get hasUnread => _unreadCount > 0;

  NotificationController._internal() {
    _initAuthListener();
  }

  void _initAuthListener() {
    _authSubscription?.cancel();
    try {
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
        _startSubscriptionForUser(user?.uid);
      });
      final currentUid = FirebaseAuth.instance.currentUser?.uid;
      _startSubscriptionForUser(currentUid);
    } catch (e) {
      debugPrint('NotificationController auth listener omitted in non-Firebase test environment: $e');
    }
  }

  void _startSubscriptionForUser(String? uid) {
    _notificationsSubscription?.cancel();
    if (uid != null && uid.isNotEmpty) {
      _notificationsSubscription = _repository.watchNotifications(uid).listen((items) {
        _notifications = items;
        _unreadCount = items.where((n) => !n.isRead).length;
        notifyListeners();
      }, onError: (error) {
        debugPrint('NotificationController stream error: $error');
      });
    } else {
      _notifications = [];
      _unreadCount = 0;
      notifyListeners();
    }
  }

  Future<void> markAsRead(String notificationId) async {
    final idx = _notifications.indexWhere((n) => n.id == notificationId);
    if (idx != -1 && _notifications[idx].isRead) return;

    if (idx != -1) {
      _notifications[idx] = _notifications[idx].copyWith(isRead: true);
      _unreadCount = _notifications.where((n) => !n.isRead).length;
      notifyListeners();
    }

    await _repository.markAsRead(notificationId);
  }

  Future<void> markAllAsRead() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;

    _notifications = _notifications.map((n) => n.copyWith(isRead: true)).toList();
    _unreadCount = 0;
    notifyListeners();

    await _repository.markAllAsRead(uid);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _notificationsSubscription?.cancel();
    super.dispose();
  }
}
