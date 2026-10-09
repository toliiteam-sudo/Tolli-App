import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../models/chat_message_model.dart';
import '../services/firestore_service.dart';

class CommunityRepository {
  final FirestoreService _firestoreService = FirestoreService.instance;

  /// Real-time stream of community messages ordered by creation time
  Stream<List<ChatMessageModel>> watchCommunityMessages({
    String communityId = 'global',
    required String currentUid,
    int limit = 50,
  }) {
    return _firestoreService.communityCollection
        .doc(communityId)
        .collection('messages')
        .orderBy('createdAt', descending: false)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return ChatMessageModel.fromFirestore(doc, currentUid);
      }).toList();
    }).handleError((error) {
      debugPrint('Error in watchCommunityMessages stream: $error');
      return <ChatMessageModel>[];
    });
  }

  /// Send a community message
  Future<bool> sendCommunityMessage({
    String communityId = 'global',
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;

    try {
      final msgDocRef = _firestoreService.communityCollection
          .doc(communityId)
          .collection('messages')
          .doc();

      await msgDocRef.set({
        'senderId': senderId,
        'senderName': senderName,
        'senderPhotoUrl': senderPhotoUrl,
        'text': trimmed,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Successfully sent community message in "$communityId"');
      return true;
    } catch (e) {
      debugPrint('Error sending community message: $e');
      return false;
    }
  }

  /// Upload image to Firebase Storage and return download URL
  Future<String?> uploadChatImage({
    required String communityId,
    required dynamic imageFile, // XFile
  }) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${imageFile.name}';
      final ref = FirebaseStorage.instance
          .ref()
          .child('chat_images')
          .child(communityId)
          .child(fileName);

      final bytes = await imageFile.readAsBytes();
      final uploadTask = await ref.putData(
        bytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final downloadUrl = await uploadTask.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading chat image: $e');
      return null;
    }
  }

  /// Send an image message
  Future<bool> sendImageMessage({
    String communityId = 'global',
    required String senderId,
    required String senderName,
    String? senderPhotoUrl,
    required String imageUrl,
    String text = '📷 Photo',
  }) async {
    try {
      final msgDocRef = _firestoreService.communityCollection
          .doc(communityId)
          .collection('messages')
          .doc();

      await msgDocRef.set({
        'senderId': senderId,
        'senderName': senderName,
        'senderPhotoUrl': senderPhotoUrl,
        'text': text,
        'type': 'image',
        'imageUrl': imageUrl,
        'createdAt': FieldValue.serverTimestamp(),
      });

      debugPrint('Successfully sent image message in "$communityId"');
      return true;
    } catch (e) {
      debugPrint('Error sending image message: $e');
      return false;
    }
  }

  /// Stream of user's real joined communities from Firestore
  Stream<List<String>> watchJoinedCommunityIds(String uid) {
    if (uid.isEmpty) return Stream.value([]);
    return _firestoreService.usersCollection
        .doc(uid)
        .collection('joined_communities')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => doc.id).toList())
        .handleError((error) {
      debugPrint('Error in watchJoinedCommunityIds stream: $error');
      return <String>[];
    });
  }

  /// Join a community genuinely: creates membership and dispatches system event message ONCE
  Future<bool> joinCommunity({
    required String communityId,
    required String uid,
    required String userName,
    String? userPhotoUrl,
    required String communityTitle,
  }) async {
    if (uid.isEmpty || communityId.isEmpty) return false;

    try {
      final memberRef = _firestoreService.communityCollection
          .doc(communityId)
          .collection('members')
          .doc(uid);

      final userJoinedRef = _firestoreService.usersCollection
          .doc(uid)
          .collection('joined_communities')
          .doc(communityId);

      final memberDoc = await memberRef.get();
      if (!memberDoc.exists) {
        final batch = _firestoreService.db.batch();

        batch.set(memberRef, {
          'uid': uid,
          'name': userName,
          'photoUrl': userPhotoUrl,
          'joinedAt': FieldValue.serverTimestamp(),
        });

        batch.set(userJoinedRef, {
          'communityId': communityId,
          'title': communityTitle,
          'joinedAt': FieldValue.serverTimestamp(),
        });

        final msgDocRef = _firestoreService.communityCollection
            .doc(communityId)
            .collection('messages')
            .doc();

        batch.set(msgDocRef, {
          'senderId': uid,
          'senderName': userName,
          'senderPhotoUrl': userPhotoUrl,
          'text': '$userName joined the community',
          'type': 'system',
          'eventType': 'user_joined',
          'createdAt': FieldValue.serverTimestamp(),
        });

        await batch.commit();
        debugPrint('Successfully joined community $communityId for $uid');
      }
      return true;
    } catch (e) {
      debugPrint('Error joining community: $e');
      return false;
    }
  }

  /// Leave a community
  Future<bool> leaveCommunity({
    required String communityId,
    required String uid,
  }) async {
    if (uid.isEmpty || communityId.isEmpty) return false;

    try {
      final batch = _firestoreService.db.batch();

      final memberRef = _firestoreService.communityCollection
          .doc(communityId)
          .collection('members')
          .doc(uid);
      batch.delete(memberRef);

      final userJoinedRef = _firestoreService.usersCollection
          .doc(uid)
          .collection('joined_communities')
          .doc(communityId);
      batch.delete(userJoinedRef);

      await batch.commit();
      debugPrint('Successfully left community $communityId for $uid');
      return true;
    } catch (e) {
      debugPrint('Error leaving community: $e');
      return false;
    }
  }
}
