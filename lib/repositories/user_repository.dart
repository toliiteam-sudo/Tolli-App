import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_profile_model.dart';
import '../services/firestore_service.dart';

class UserRepository {
  final FirestoreService _firestoreService = FirestoreService.instance;

  Future<UserProfileModel?> getUserProfile(String uid) async {
    try {
      final doc = await _firestoreService.usersCollection.doc(uid).get();
      if (doc.exists && doc.data() != null) {
        return UserProfileModel.fromSnapshot(doc);
      }
    } catch (e) {
      debugPrint('Error fetching user profile from Firestore for uid $uid: $e');
    }
    return null;
  }

  Future<bool> saveUserProfile(UserProfileModel profile) async {
    try {
      await _firestoreService.usersCollection
          .doc(profile.uid)
          .set(profile.toMap(), SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('Error saving user profile to Firestore for uid ${profile.uid}: $e');
      return false;
    }
  }

  Future<bool> updateProfileData(String uid, Map<String, dynamic> data) async {
    try {
      final updateData = Map<String, dynamic>.from(data);
      updateData['updatedAt'] = FieldValue.serverTimestamp();
      await _firestoreService.usersCollection.doc(uid).update(updateData);
      return true;
    } catch (e) {
      debugPrint('Error updating user profile data for uid $uid: $e');
      return false;
    }
  }

  Stream<UserProfileModel?> streamUserProfile(String uid) {
    return _firestoreService.usersCollection.doc(uid).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return UserProfileModel.fromSnapshot(doc);
      }
      return null;
    });
  }
}
