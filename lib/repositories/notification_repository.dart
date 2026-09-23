import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/notification_model.dart';
import '../services/firestore_service.dart';

class NotificationRepository {
  final FirestoreService _firestoreService = FirestoreService.instance;

  /// Real-time stream of notifications for a specific recipient UID sorted newest first
  Stream<List<NotificationModel>> watchNotifications(String recipientUid) {
    if (recipientUid.isEmpty) return Stream.value([]);

    return _firestoreService.db
        .collection('notifications')
        .where('recipientId', isEqualTo: recipientUid)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => NotificationModel.fromFirestore(doc))
          .toList();
      // Sort client side to avoid requiring composite indexes initially
      list.sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
      return list;
    }).handleError((error) {
      debugPrint('Error watching notifications: $error');
      return <NotificationModel>[];
    });
  }

  /// Real-time stream of unread notification count for a recipient UID
  Stream<int> watchUnreadCount(String recipientUid) {
    if (recipientUid.isEmpty) return Stream.value(0);

    return _firestoreService.db
        .collection('notifications')
        .where('recipientId', isEqualTo: recipientUid)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length)
        .handleError((error) {
      debugPrint('Error watching unread notification count: $error');
      return 0;
    });
  }

  /// Create a new notification in Firestore
  Future<bool> createNotification(NotificationModel notification) async {
    if (notification.recipientId.isEmpty) return false;

    try {
      final docRef = _firestoreService.db.collection('notifications').doc();
      final data = notification.toFirestore();
      await docRef.set(data);
      debugPrint('Successfully created notification for recipient ${notification.recipientId}');
      return true;
    } catch (e) {
      debugPrint('Error creating notification: $e');
      return false;
    }
  }

  /// Mark a single notification as read in Firestore
  Future<bool> markAsRead(String notificationId) async {
    if (notificationId.isEmpty) return false;

    try {
      await _firestoreService.db
          .collection('notifications')
          .doc(notificationId)
          .update({'isRead': true});
      return true;
    } catch (e) {
      debugPrint('Error marking notification as read: $e');
      return false;
    }
  }

  /// Mark all unread notifications for a recipient UID as read in Firestore
  Future<bool> markAllAsRead(String recipientUid) async {
    if (recipientUid.isEmpty) return false;

    try {
      final query = await _firestoreService.db
          .collection('notifications')
          .where('recipientId', isEqualTo: recipientUid)
          .where('isRead', isEqualTo: false)
          .get();

      if (query.docs.isEmpty) return true;

      final batch = _firestoreService.db.batch();
      for (final doc in query.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('Error marking all notifications as read: $e');
      return false;
    }
  }
}
