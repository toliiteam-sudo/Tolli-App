import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/activity_model.dart';
import '../models/activity_request_model.dart';
import '../models/notification_model.dart';
import '../repositories/notification_repository.dart';
import '../services/firestore_service.dart';

class RxStreamCombine {
  static Stream<R> combineTwo<A, B, R>(
    Stream<A> streamA,
    Stream<B> streamB,
    R Function(A a, B b) combiner,
  ) {
    late StreamController<R> controller;
    StreamSubscription<A>? subA;
    StreamSubscription<B>? subB;
    A? lastA;
    B? lastB;
    bool hasA = false;
    bool hasB = false;

    void update() {
      if (hasA || hasB) {
        final valA = hasA ? lastA! : ([] as A);
        final valB = hasB ? lastB! : ([] as B);
        controller.add(combiner(valA, valB));
      }
    }

    controller = StreamController<R>(
      onListen: () {
        subA = streamA.listen((a) {
          lastA = a;
          hasA = true;
          update();
        }, onError: controller.addError);
        subB = streamB.listen((b) {
          lastB = b;
          hasB = true;
          update();
        }, onError: controller.addError);
      },
      onCancel: () {
        subA?.cancel();
        subB?.cancel();
      },
    );

    return controller.stream;
  }

  static Stream<R> combineThree<A, B, C, R>(
    Stream<A> streamA,
    Stream<B> streamB,
    Stream<C> streamC,
    R Function(A? a, B? b, C? c) combiner,
  ) {
    late StreamController<R> controller;
    StreamSubscription<A>? subA;
    StreamSubscription<B>? subB;
    StreamSubscription<C>? subC;
    A? lastA;
    B? lastB;
    C? lastC;
    bool hasA = false;
    bool hasB = false;
    bool hasC = false;

    void update() {
      if (hasA || hasB || hasC) {
        controller.add(combiner(lastA, lastB, lastC));
      }
    }

    controller = StreamController<R>(
      onListen: () {
        subA = streamA.listen((a) {
          lastA = a;
          hasA = true;
          update();
        }, onError: controller.addError);
        subB = streamB.listen((b) {
          lastB = b;
          hasB = true;
          update();
        }, onError: controller.addError);
        subC = streamC.listen((c) {
          lastC = c;
          hasC = true;
          update();
        }, onError: controller.addError);
      },
      onCancel: () {
        subA?.cancel();
        subB?.cancel();
        subC?.cancel();
      },
    );

    return controller.stream;
  }
}

class ActivityRepository {
  final FirestoreService _firestoreService = FirestoreService.instance;

  /// Stream of all real-time activities from Firestore (filtered for Explore)
  Stream<List<ActivityModel>> watchActivities({String? currentUid}) {
    return _firestoreService.activitiesCollection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ActivityModel.fromFirestore(doc, currentUid: currentUid);
      }).where((activity) {
        if (activity.status == 'cancelled') return false;
        final isParticipant = currentUid != null &&
            currentUid.isNotEmpty &&
            (activity.hostId == currentUid ||
                activity.isHost ||
                (activity.participantIds != null && activity.participantIds!.contains(currentUid)));
        if (!isParticipant && (activity.isExpired || activity.joinedPlayers >= activity.totalPlayers)) {
          return false;
        }
        return true;
      }).toList();
    }).handleError((error) {
      debugPrint('Error in watchActivities stream: $error');
      return <ActivityModel>[];
    });
  }

  /// Stream of activities where [uid] is a host or approved participant (Upcoming Activities)
  Stream<List<ActivityModel>> watchUserUpcomingActivities(String uid) {
    if (uid.isEmpty) return Stream.value([]);
    
    final participantStream = _firestoreService.activitiesCollection
        .where('participantIds', arrayContains: uid)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ActivityModel.fromFirestore(doc, currentUid: uid)).toList())
        .handleError((error) {
      debugPrint('Error in watchUserUpcomingActivities participantStream: $error');
      return <ActivityModel>[];
    });

    final hostStream = _firestoreService.activitiesCollection
        .where('hostId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => ActivityModel.fromFirestore(doc, currentUid: uid)).toList())
        .handleError((error) {
      debugPrint('Error in watchUserUpcomingActivities hostStream: $error');
      return <ActivityModel>[];
    });

    return RxStreamCombine.combineTwo<
        List<ActivityModel>,
        List<ActivityModel>,
        List<ActivityModel>>(
      hostStream,
      participantStream,
      (hosts, parts) {
        debugPrint('[UPCOMING_DEBUG] currentUser.uid: $uid');
        debugPrint('[UPCOMING_DEBUG] hosted query result IDs: ${hosts.map((a) => a.id).toList()}');
        debugPrint('[UPCOMING_DEBUG] joined query result IDs: ${parts.map((a) => a.id).toList()}');

        final Map<String, ActivityModel> map = {};
        for (var a in hosts) {
          map[a.id] = a.copyWith(isHost: true);
        }
        for (var a in parts) {
          if (!map.containsKey(a.id)) {
            map[a.id] = a;
          }
        }

        debugPrint('[UPCOMING_DEBUG] merged IDs: ${map.keys.toList()}');

        final now = DateTime.now();
        final upcomingList = map.values.where((a) {
          if (a.status == 'cancelled' || a.status == 'completed' || a.status == 'expired') {
            return false;
          }
          final endTs = a.endTimestamp;
          if (endTs != null && !endTs.isAfter(now)) {
            return false;
          }
          return true;
        }).toList();

        debugPrint('[UPCOMING_DEBUG] filtered upcoming IDs: ${upcomingList.map((a) => a.id).toList()}');

        upcomingList.sort((a, b) {
          final dateA = a.date ?? DateTime.now();
          final dateB = b.date ?? DateTime.now();
          return dateA.compareTo(dateB);
        });

        debugPrint('[UPCOMING_DEBUG] final Home upcoming IDs: ${upcomingList.map((a) => '${a.title} (${a.id})').toList()}');

        return upcomingList;
      },
    );
  }

  /// Stream of activities hosted by [uid]
  Stream<List<ActivityModel>> watchUserHostedActivities(String uid) {
    return _firestoreService.activitiesCollection
        .where('hostId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ActivityModel.fromFirestore(doc, currentUid: uid);
      }).toList();
    }).handleError((error) {
      debugPrint('Error in watchUserHostedActivities stream: $error');
      return <ActivityModel>[];
    });
  }

  /// Stream of a single activity details by ID
  Stream<ActivityModel?> watchActivityDetail(String activityId, {String? currentUid}) {
    return _firestoreService.activitiesCollection
        .doc(activityId)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return ActivityModel.fromFirestore(doc, currentUid: currentUid);
    }).handleError((error) {
      debugPrint('Error in watchActivityDetail stream: $error');
      return null;
    });
  }

  /// Stream to watch if a specific user is a participant of an activity
  Stream<bool> watchUserParticipantStatus(String activityId, String uid) {
    if (uid.isEmpty) return Stream.value(false);
    return _firestoreService.activitiesCollection
        .doc(activityId)
        .collection('participants')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists)
        .handleError((error) => false);
  }

  /// Stream to watch if a specific user has a request status for an activity
  Stream<String?> watchUserRequestStatus(String activityId, String uid) {
    if (uid.isEmpty) return Stream.value(null);
    return _firestoreService.activitiesCollection
        .doc(activityId)
        .collection('requests')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? (doc.data()?['status'] as String?) : null)
        .handleError((error) => null);
  }

  /// Single source of truth stream for an activity's membership status for a given user
  Stream<ActivityMembershipStatus> watchActivityMembershipStatus(String activityId, String uid) {
    if (activityId.isEmpty || uid.isEmpty) {
      return Stream.value(ActivityMembershipStatus.notJoined);
    }

    final activityStream = _firestoreService.activitiesCollection.doc(activityId).snapshots();
    final participantStream = _firestoreService.activitiesCollection
        .doc(activityId)
        .collection('participants')
        .doc(uid)
        .snapshots();
    final requestStream = _firestoreService.activitiesCollection
        .doc(activityId)
        .collection('requests')
        .doc(uid)
        .snapshots();

    return RxStreamCombine.combineThree<
        DocumentSnapshot<Map<String, dynamic>>,
        DocumentSnapshot<Map<String, dynamic>>,
        DocumentSnapshot<Map<String, dynamic>>,
        ActivityMembershipStatus>(
      activityStream,
      participantStream,
      requestStream,
      (actSnap, partSnap, reqSnap) {
        if (actSnap == null || !actSnap.exists) return ActivityMembershipStatus.notJoined;
        final actData = actSnap.data();
        final hostId = actData?['hostId'] as String? ?? '';
        final participantIds = List<String>.from(actData?['participantIds'] ?? []);

        if (hostId.isNotEmpty && hostId == uid) {
          return ActivityMembershipStatus.host;
        }

        if ((partSnap != null && partSnap.exists) || participantIds.contains(uid)) {
          return ActivityMembershipStatus.joined;
        }

        if (reqSnap != null && reqSnap.exists) {
          final status = reqSnap.data()?['status'] as String?;
          if (status == 'pending') {
            return ActivityMembershipStatus.pending;
          }
        }

        return ActivityMembershipStatus.notJoined;
      },
    );
  }

  /// Direct join an activity in Firestore
  Future<bool> joinActivityDirectly({
    required String activityId,
    required String uid,
    required String userName,
    required String userUsername,
    String? userPhotoUrl,
  }) async {
    try {
      final batch = _firestoreService.db.batch();

      final participantRef = _firestoreService.activitiesCollection
          .doc(activityId)
          .collection('participants')
          .doc(uid);

      batch.set(participantRef, {
        'name': userName,
        'role': 'MEMBER',
        'skill': 'Intermediate',
        'avatarUrl': userPhotoUrl,
        'isHost': false,
        'joinedAt': FieldValue.serverTimestamp(),
      });

      final activityRef = _firestoreService.activitiesCollection.doc(activityId);
      batch.update(activityRef, {
        'joinedPlayers': FieldValue.increment(1),
        'participantIds': FieldValue.arrayUnion([uid]),
      });

      final conversationRef = _firestoreService.db.collection('conversations').doc(activityId);
      batch.set(conversationRef, {
        'participantIds': FieldValue.arrayUnion([uid]),
      }, SetOptions(merge: true));

      await batch.commit();
      debugPrint('Successfully joined activity "$activityId" directly for user "$uid"');
      return true;
    } catch (e) {
      debugPrint('Error joining activity directly: $e');
      return false;
    }
  }

  /// Leave an activity in Firestore
  Future<bool> leaveActivity(String activityId, String uid) async {
    return removeParticipant(activityId, uid);
  }

  /// Create a new activity in Firestore
  Future<String?> createActivity({
    required ActivityModel activity,
    required String hostUid,
    required String hostName,
    required String hostUsername,
    String? hostPhotoUrl,
  }) async {
    try {
      final docRef = _firestoreService.activitiesCollection.doc();
      final String activityId = docRef.id;

      final updatedActivity = activity.copyWith(
        id: activityId,
        hostId: hostUid,
        hostName: hostName,
        hostUsername: hostUsername,
        hostPhotoUrl: hostPhotoUrl,
        joinedPlayers: 1,
        participantIds: [hostUid],
      );

      final batch = _firestoreService.db.batch();

      // 1. Create main activity document
      batch.set(docRef, updatedActivity.toFirestore());

      // 2. Add host as first participant in subcollection
      final participantRef = docRef.collection('participants').doc(hostUid);
      batch.set(participantRef, {
        'name': hostName,
        'role': 'HOST',
        'skill': updatedActivity.skillLevel.label,
        'avatarUrl': hostPhotoUrl,
        'isHost': true,
        'joinedAt': FieldValue.serverTimestamp(),
      });

      // 3. Automatically create associated temporary group conversation in Firestore
      final conversationRef = _firestoreService.db.collection('conversations').doc(activityId);
      batch.set(conversationRef, {
        'id': activityId,
        'activityId': activityId,
        'title': '${updatedActivity.title} Chat',
        'type': 'activity_group',
        'participantIds': [hostUid],
        'lastMessage': 'Group chat created for ${updatedActivity.title}',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      });

      await batch.commit();
      debugPrint('Successfully created activity "$activityId" in Firestore');
      return activityId;
    } catch (e) {
      debugPrint('Error creating activity in Firestore: $e');
      rethrow;
    }
  }

  /// Submit a request to join an activity
  Future<bool> requestToJoinActivity({
    required String activityId,
    required String uid,
    required String userName,
    required String userUsername,
    String? userPhotoUrl,
  }) async {
    try {
      final reqDocRef = _firestoreService.activitiesCollection
          .doc(activityId)
          .collection('requests')
          .doc(uid);

      await reqDocRef.set({
        'activityId': activityId,
        'status': 'pending',
        'userName': userName,
        'userUsername': userUsername,
        'userPhotoUrl': userPhotoUrl,
        'requestedAt': FieldValue.serverTimestamp(),
      });

      // Dispatch notification to host
      final activityDoc = await _firestoreService.activitiesCollection.doc(activityId).get();
      final hostId = activityDoc.data()?['hostId'] as String? ?? '';
      final actTitle = activityDoc.data()?['title'] as String? ?? 'Activity';

      if (hostId.isNotEmpty && hostId != uid) {
        await NotificationRepository().createNotification(
          NotificationModel(
            id: '',
            recipientId: hostId,
            type: 'join_request',
            title: 'New join request',
            body: '$userName requested to join $actTitle',
            createdAt: DateTime.now(),
            isRead: false,
            relatedActivityId: activityId,
            senderId: uid,
            senderName: userName,
            senderPhotoUrl: userPhotoUrl,
            requestStatus: 'PENDING',
          ),
        );
      }

      debugPrint('Successfully submitted join request for activity "$activityId" by user "$uid"');
      return true;
    } catch (e) {
      debugPrint('Error submitting join request: $e');
      return false;
    }
  }

  /// Stream of pending join requests for an activity
  Stream<List<ActivityRequestModel>> watchActivityRequests(String activityId) {
    return _firestoreService.activitiesCollection
        .doc(activityId)
        .collection('requests')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => ActivityRequestModel.fromFirestore(doc)).toList();
    }).handleError((error) {
      debugPrint('Error watching activity requests: $error');
      return <ActivityRequestModel>[];
    });
  }

  /// Host accepts or rejects a join request
  Future<bool> respondToJoinRequest({
    required String activityId,
    required ActivityRequestModel request,
    required bool accept,
  }) async {
    try {
      final batch = _firestoreService.db.batch();
      final reqDocRef = _firestoreService.activitiesCollection
          .doc(activityId)
          .collection('requests')
          .doc(request.uid);

      if (accept) {
        batch.update(reqDocRef, {'status': 'accepted'});

        final participantRef = _firestoreService.activitiesCollection
            .doc(activityId)
            .collection('participants')
            .doc(request.uid);

        batch.set(participantRef, {
          'name': request.userName,
          'role': 'MEMBER',
          'skill': 'Intermediate',
          'avatarUrl': request.userPhotoUrl,
          'isHost': false,
          'joinedAt': FieldValue.serverTimestamp(),
        });

        // Increment joinedPlayers count atomically and add participantUid to participantIds
        final activityRef = _firestoreService.activitiesCollection.doc(activityId);
        batch.update(activityRef, {
          'joinedPlayers': FieldValue.increment(1),
          'participantIds': FieldValue.arrayUnion([request.uid]),
        });
      } else {
        batch.update(reqDocRef, {'status': 'rejected'});
      }

      await batch.commit();

      // Dispatch notification to applicant
      final activityDoc = await _firestoreService.activitiesCollection.doc(activityId).get();
      final actTitle = activityDoc.data()?['title'] as String? ?? 'Activity';

      if (accept) {
        await NotificationRepository().createNotification(
          NotificationModel(
            id: '',
            recipientId: request.uid,
            type: 'request_accepted',
            title: 'Request accepted!',
            body: 'Your request to join $actTitle was accepted.',
            createdAt: DateTime.now(),
            isRead: false,
            relatedActivityId: activityId,
            senderId: FirebaseAuth.instance.currentUser?.uid,
            requestStatus: 'APPROVED',
          ),
        );
      } else {
        await NotificationRepository().createNotification(
          NotificationModel(
            id: '',
            recipientId: request.uid,
            type: 'request_rejected',
            title: 'Request declined',
            body: 'Your request to join $actTitle was declined.',
            createdAt: DateTime.now(),
            isRead: false,
            relatedActivityId: activityId,
            senderId: FirebaseAuth.instance.currentUser?.uid,
            requestStatus: 'DECLINED',
          ),
        );
      }

      return true;
    } catch (e) {
      debugPrint('Error responding to join request: $e');
      return false;
    }
  }

  /// Stream of real participants for an activity
  Stream<List<PlayerModel>> watchActivityParticipants(String activityId) {
    return _firestoreService.activitiesCollection
        .doc(activityId)
        .collection('participants')
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => PlayerModel.fromFirestore(doc)).toList();
    }).handleError((error) {
      debugPrint('Error watching activity participants: $error');
      return <PlayerModel>[];
    });
  }

  /// Remove a participant from an activity
  Future<bool> removeParticipant(String activityId, String playerId) async {
    try {
      final batch = _firestoreService.db.batch();
      final participantRef = _firestoreService.activitiesCollection
          .doc(activityId)
          .collection('participants')
          .doc(playerId);
      batch.delete(participantRef);

      final activityRef = _firestoreService.activitiesCollection.doc(activityId);
      batch.update(activityRef, {
        'joinedPlayers': FieldValue.increment(-1),
        'participantIds': FieldValue.arrayRemove([playerId]),
      });

      final conversationRef = _firestoreService.db.collection('conversations').doc(activityId);
      batch.set(conversationRef, {
        'participantIds': FieldValue.arrayRemove([playerId]),
      }, SetOptions(merge: true));

      await batch.commit();
      debugPrint('Successfully removed participant "$playerId" from activity "$activityId"');
      return true;
    } catch (e) {
      debugPrint('Batch remove participant failed ($e). Falling back to participant doc deletion.');
      try {
        await _firestoreService.activitiesCollection
            .doc(activityId)
            .collection('participants')
            .doc(playerId)
            .delete();
        debugPrint('Fallback participant document deletion succeeded for "$playerId"');
        return true;
      } catch (fallbackError) {
        debugPrint('Fallback participant deletion error: $fallbackError');
        return false;
      }
    }
  }

  /// Delete activity from Firestore
  Future<bool> deleteActivity(String activityId) async {
    try {
      await _firestoreService.activitiesCollection.doc(activityId).delete();
      debugPrint('Successfully deleted activity "$activityId" from Firestore');
      return true;
    } catch (e) {
      debugPrint('Error deleting activity from Firestore: $e');
      return false;
    }
  }

  /// Update an existing activity document in Firestore
  Future<bool> updateActivity(ActivityModel activity) async {
    try {
      await _firestoreService.activitiesCollection
          .doc(activity.id)
          .update(activity.toFirestore());
      debugPrint('Successfully updated activity "${activity.id}" in Firestore');
      return true;
    } catch (e) {
      debugPrint('Error updating activity in Firestore: $e');
      return false;
    }
  }
}
