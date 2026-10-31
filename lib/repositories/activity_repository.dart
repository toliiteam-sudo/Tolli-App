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
        final valA = hasA ? lastA! : (<ActivityModel>[] is A ? <ActivityModel>[] as A : (lastA ?? <dynamic>[] as dynamic));
        final valB = hasB ? lastB! : (<ActivityModel>[] is B ? <ActivityModel>[] as B : (lastB ?? <dynamic>[] as dynamic));
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

  /// Direct join an activity in Firestore with atomic validation
  Future<bool> joinActivityDirectly({
    required String activityId,
    required String uid,
    required String userName,
    required String userUsername,
    String? userPhotoUrl,
  }) async {
    if (activityId.isEmpty || uid.isEmpty) return false;

    try {
      final activityRef = _firestoreService.activitiesCollection.doc(activityId);
      final participantRef = activityRef.collection('participants').doc(uid);
      final conversationRef = _firestoreService.conversationsCollection.doc(activityId);

      return await _firestoreService.db.runTransaction<bool>((transaction) async {
        final activityDoc = await transaction.get(activityRef);
        if (!activityDoc.exists) {
          debugPrint('Cannot join: Activity $activityId does not exist.');
          return false;
        }

        final data = activityDoc.data() ?? {};
        final status = (data['status'] as String? ?? 'scheduled').toLowerCase();
        if (status == 'cancelled' || status == 'completed' || status == 'expired') {
          debugPrint('Cannot join: Activity is $status.');
          return false;
        }

        // Check if activity expired by date or end timestamp
        final endTs = data['endTimestamp'] as Timestamp?;
        if (endTs != null && endTs.toDate().isBefore(DateTime.now())) {
          debugPrint('Cannot join: Activity has expired.');
          return false;
        }
        final dateTs = data['date'] as Timestamp?;
        if (dateTs != null && dateTs.toDate().add(const Duration(hours: 4)).isBefore(DateTime.now())) {
          debugPrint('Cannot join: Activity date has passed.');
          return false;
        }

        final hostId = data['hostId'] as String? ?? '';
        if (hostId.isNotEmpty && hostId == uid) {
          debugPrint('Host cannot join their own activity as participant.');
          return false;
        }

        final participantIds = List<String>.from(data['participantIds'] ?? []);
        if (participantIds.contains(uid)) {
          // Already joined -> idempotent success, do not increment player count
          debugPrint('User $uid is already a participant of activity $activityId.');
          return true;
        }

        final totalPlayers = data['totalPlayers'] as int? ?? 4;
        final joinedPlayers = data['joinedPlayers'] as int? ?? 1;
        if (joinedPlayers >= totalPlayers) {
          debugPrint('Cannot join: Activity $activityId is full ($joinedPlayers/$totalPlayers).');
          return false;
        }

        // Check conversation exists before updating it in transaction
        final convDoc = await transaction.get(conversationRef);

        // Perform writes
        transaction.set(participantRef, {
          'name': userName,
          'role': 'MEMBER',
          'skill': 'Intermediate',
          'avatarUrl': userPhotoUrl,
          'isHost': false,
          'joinedAt': FieldValue.serverTimestamp(),
        });

        transaction.update(activityRef, {
          'joinedPlayers': joinedPlayers + 1,
          'participantIds': FieldValue.arrayUnion([uid]),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (convDoc.exists) {
          transaction.update(conversationRef, {
            'participantIds': FieldValue.arrayUnion([uid]),
          });
        }

        return true;
      });
    } catch (e) {
      debugPrint('Error joining activity directly: $e');
      return false;
    }
  }

  /// Leave an activity in Firestore
  Future<bool> leaveActivity(String activityId, String uid) async {
    if (activityId.isEmpty || uid.isEmpty) return false;
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

  /// Submit a request to join an activity with validation
  Future<bool> requestToJoinActivity({
    required String activityId,
    required String uid,
    required String userName,
    required String userUsername,
    String? userPhotoUrl,
  }) async {
    if (activityId.isEmpty || uid.isEmpty) return false;

    try {
      final activityDoc = await _firestoreService.activitiesCollection.doc(activityId).get();
      if (!activityDoc.exists) return false;

      final data = activityDoc.data() ?? {};
      final status = (data['status'] as String? ?? 'scheduled').toLowerCase();
      if (status == 'cancelled' || status == 'completed' || status == 'expired') {
        debugPrint('Cannot request: Activity is $status.');
        return false;
      }

      final hostId = data['hostId'] as String? ?? '';
      if (hostId == uid) {
        debugPrint('Host cannot request to join their own activity.');
        return false;
      }

      final participantIds = List<String>.from(data['participantIds'] ?? []);
      if (participantIds.contains(uid)) {
        debugPrint('User is already a participant.');
        return false;
      }

      final totalPlayers = data['totalPlayers'] as int? ?? 4;
      final joinedPlayers = data['joinedPlayers'] as int? ?? 1;
      if (joinedPlayers >= totalPlayers) {
        debugPrint('Cannot request: Activity is full.');
        return false;
      }

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
      final actTitle = data['title'] as String? ?? 'Activity';
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

  /// Host accepts or rejects a join request with capacity validation
  Future<bool> respondToJoinRequest({
    required String activityId,
    required ActivityRequestModel request,
    required bool accept,
  }) async {
    if (activityId.isEmpty || request.uid.isEmpty) return false;

    try {
      final reqDocRef = _firestoreService.activitiesCollection
          .doc(activityId)
          .collection('requests')
          .doc(request.uid);

      if (!accept) {
        await reqDocRef.update({'status': 'rejected'});
        final activityDoc = await _firestoreService.activitiesCollection.doc(activityId).get();
        final actTitle = activityDoc.data()?['title'] as String? ?? 'Activity';

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
        return true;
      }

      final activityRef = _firestoreService.activitiesCollection.doc(activityId);
      final participantRef = activityRef.collection('participants').doc(request.uid);
      final conversationRef = _firestoreService.conversationsCollection.doc(activityId);

      final accepted = await _firestoreService.db.runTransaction<bool>((transaction) async {
        final activityDoc = await transaction.get(activityRef);
        if (!activityDoc.exists) return false;

        final data = activityDoc.data() ?? {};
        final participantIds = List<String>.from(data['participantIds'] ?? []);
        final totalPlayers = data['totalPlayers'] as int? ?? 4;
        final joinedPlayers = data['joinedPlayers'] as int? ?? 1;

        if (participantIds.contains(request.uid)) {
          transaction.update(reqDocRef, {'status': 'accepted'});
          return true;
        }

        if (joinedPlayers >= totalPlayers) {
          debugPrint('Cannot approve join request: Activity is already full.');
          return false;
        }

        final convDoc = await transaction.get(conversationRef);

        transaction.update(reqDocRef, {'status': 'accepted'});
        transaction.set(participantRef, {
          'name': request.userName,
          'role': 'MEMBER',
          'skill': 'Intermediate',
          'avatarUrl': request.userPhotoUrl,
          'isHost': false,
          'joinedAt': FieldValue.serverTimestamp(),
        });
        transaction.update(activityRef, {
          'joinedPlayers': joinedPlayers + 1,
          'participantIds': FieldValue.arrayUnion([request.uid]),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (convDoc.exists) {
          transaction.update(conversationRef, {
            'participantIds': FieldValue.arrayUnion([request.uid]),
          });
        }
        return true;
      });

      if (accepted) {
        final activityDoc = await _firestoreService.activitiesCollection.doc(activityId).get();
        final actTitle = activityDoc.data()?['title'] as String? ?? 'Activity';

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
      }

      return accepted;
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

  /// Remove a participant from an activity atomically
  Future<bool> removeParticipant(String activityId, String playerId) async {
    if (activityId.isEmpty || playerId.isEmpty) return false;

    try {
      final activityRef = _firestoreService.activitiesCollection.doc(activityId);
      final participantRef = activityRef.collection('participants').doc(playerId);
      final conversationRef = _firestoreService.conversationsCollection.doc(activityId);

      return await _firestoreService.db.runTransaction<bool>((transaction) async {
        final activityDoc = await transaction.get(activityRef);
        if (!activityDoc.exists) return false;

        final data = activityDoc.data() ?? {};
        final hostId = data['hostId'] as String? ?? '';
        if (hostId.isNotEmpty && hostId == playerId) {
          debugPrint('Host cannot leave their own activity through removeParticipant.');
          return false;
        }

        final participantIds = List<String>.from(data['participantIds'] ?? []);
        if (!participantIds.contains(playerId)) {
          debugPrint('Participant $playerId is already not in activity $activityId.');
          return true;
        }

        final currentJoined = data['joinedPlayers'] as int? ?? 1;
        final newJoined = (currentJoined - 1).clamp(0, 9999);

        final convDoc = await transaction.get(conversationRef);

        transaction.delete(participantRef);
        transaction.update(activityRef, {
          'joinedPlayers': newJoined,
          'participantIds': FieldValue.arrayRemove([playerId]),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        if (convDoc.exists) {
          transaction.update(conversationRef, {
            'participantIds': FieldValue.arrayRemove([playerId]),
          });
        }

        return true;
      });
    } catch (e) {
      debugPrint('Transaction remove participant failed: $e');
      return false;
    }
  }

  /// Delete activity from Firestore (host only, notifies participants, preserves bookings)
  Future<bool> deleteActivity(String activityId) async {
    if (activityId.isEmpty) return false;

    try {
      final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final docRef = _firestoreService.activitiesCollection.doc(activityId);
      final docSnap = await docRef.get();
      if (!docSnap.exists) {
        debugPrint('Activity "$activityId" already deleted or does not exist.');
        return true;
      }

      final data = docSnap.data() ?? {};
      final hostId = data['hostId'] as String? ?? '';
      if (currentUid.isNotEmpty && hostId.isNotEmpty && hostId != currentUid) {
        debugPrint('Unauthorized: user "$currentUid" is not host "$hostId" of activity "$activityId".');
        return false;
      }

      // Notify non-host participants before deletion
      final participantIds = List<String>.from(data['participantIds'] ?? []);
      final title = data['title'] as String? ?? 'Activity';
      for (final pId in participantIds) {
        if (pId.isNotEmpty && pId != hostId) {
          try {
            await NotificationRepository().createNotification(
              NotificationModel(
                id: '',
                recipientId: pId,
                type: 'activity_cancelled',
                title: 'Activity Cancelled',
                body: '$title has been cancelled by the host.',
                createdAt: DateTime.now(),
                isRead: false,
                relatedActivityId: activityId,
                senderId: hostId,
              ),
            );
          } catch (notifErr) {
            debugPrint('Failed to dispatch cancellation notification to $pId: $notifErr');
          }
        }
      }

      await docRef.delete();
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
