import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../services/firestore_service.dart';
import '../utils/username_validator.dart';

enum UsernameCheckResult {
  available,
  taken,
  error,
}

class UsernameTakenException implements Exception {
  final String message;
  UsernameTakenException([this.message = 'Username is already taken']);

  @override
  String toString() => message;
}

class UsernameRepository {
  final FirestoreService _firestoreService = FirestoreService.instance;

  static String normalize(String username) => UsernameValidator.normalize(username);
  static bool isReserved(String username) => UsernameValidator.isReserved(username);
  static bool isValidFormat(String username) => UsernameValidator.isValidFormat(username);
  static String generateBaseUsername(String firstName, String lastName) =>
      UsernameValidator.generateBaseUsername(firstName, lastName);

  Future<UsernameCheckResult> checkUsernameAvailabilityRemote(String username, {String? currentUid}) async {
    final norm = UsernameValidator.normalize(username);
    if (!UsernameValidator.isValidFormat(norm)) return UsernameCheckResult.taken;

    debugPrint('=== FIRESTORE USERNAME CHECK DIAGNOSTICS ===');
    debugPrint('USERNAME RAW: $username');
    debugPrint('USERNAME NORMALIZED: $norm');
    debugPrint('AUTH UID PRESENT: ${currentUid != null} (uid: $currentUid)');
    debugPrint('FIRESTORE LOOKUP PATH: usernames/$norm');

    try {
      final doc = await _firestoreService.usernamesCollection.doc(norm).get();
      final exists = doc.exists;
      debugPrint('DOCUMENT EXISTS: $exists');

      if (!exists) {
        debugPrint('AVAILABILITY RESULT: AVAILABLE (document does not exist)');
        return UsernameCheckResult.available;
      }

      final data = doc.data();
      final docUid = data != null ? data['uid'] as String? : null;
      debugPrint('DOCUMENT UID: $docUid');
      debugPrint('CURRENT AUTH UID: $currentUid');

      if (docUid != null && currentUid != null && docUid == currentUid) {
        debugPrint('AVAILABILITY RESULT: AVAILABLE (owned by current authenticated user)');
        return UsernameCheckResult.available;
      }

      debugPrint('AVAILABILITY RESULT: TAKEN (owned by another user)');
      return UsernameCheckResult.taken;
    } catch (e) {
      debugPrint('EXCEPTION TYPE: ${e.runtimeType}');
      if (e is FirebaseException) {
        debugPrint('EXCEPTION CODE: ${e.code}');
        debugPrint('EXCEPTION MESSAGE: ${e.message}');
        if (e.code == 'permission-denied') {
          debugPrint('WARNING: [FIRESTORE PERMISSION DENIED] Check that firestore.rules are published to Firebase Console!');
        }
      } else {
        debugPrint('EXCEPTION MESSAGE: $e');
      }
      debugPrint('AVAILABILITY RESULT: ERROR (query failed)');
      return UsernameCheckResult.error;
    }
  }

  Future<bool> isUsernameAvailableRemote(String username, {String? currentUid}) async {
    final result = await checkUsernameAvailabilityRemote(username, currentUid: currentUid);
    return result == UsernameCheckResult.available;
  }

  Future<bool> claimUsernameAtomic({
    required String uid,
    required String newUsername,
    String? oldUsername,
  }) async {
    final normNew = UsernameValidator.normalize(newUsername);
    if (!UsernameValidator.isValidFormat(normNew)) {
      throw Exception('Invalid username format or reserved name');
    }

    final normOld = (oldUsername != null && oldUsername.trim().isNotEmpty)
        ? UsernameValidator.normalize(oldUsername)
        : null;

    try {
      await _firestoreService.db.runTransaction((transaction) async {
        final newUsernameDocRef = _firestoreService.usernamesCollection.doc(normNew);
        final newUsernameSnap = await transaction.get(newUsernameDocRef);

        if (newUsernameSnap.exists) {
          final data = newUsernameSnap.data();
          final existingUid = data != null ? data['uid'] as String? : null;
          if (existingUid != null && existingUid != uid) {
            throw UsernameTakenException('Username is already taken by another account');
          }
        }

        if (normOld != null && normOld != normNew) {
          final oldUsernameDocRef = _firestoreService.usernamesCollection.doc(normOld);
          final oldUsernameSnap = await transaction.get(oldUsernameDocRef);
          if (oldUsernameSnap.exists && oldUsernameSnap.data()?['uid'] == uid) {
            transaction.delete(oldUsernameDocRef);
          }
        }

        // 1. Claim username document
        transaction.set(newUsernameDocRef, {
          'uid': uid,
          'username': normNew,
          'createdAt': FieldValue.serverTimestamp(),
        });

        // 2. Set user document (include 'uid' so Firestore rule 'request.resource.data.uid == userId' succeeds!)
        final userDocRef = _firestoreService.usersCollection.doc(uid);
        transaction.set(userDocRef, {
          'uid': uid,
          'username': normNew,
          'normalizedUsername': normNew,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });

      return true;
    } catch (e) {
      debugPrint('Error in atomic username claim transaction: $e');
      rethrow;
    }
  }

  /// Automatically generates a clean, unique username derived from First Name + Last Name
  /// and claims it atomically via Firestore transaction.
  /// If [oldUsername] is already set for this [uid], it preserves it without changing it.
  Future<String> generateAndClaimUniqueUsername({
    required String uid,
    required String firstName,
    required String lastName,
    String? oldUsername,
  }) async {
    // 1. If user already has an assigned username, preserve it!
    if (oldUsername != null && oldUsername.trim().isNotEmpty) {
      final normOld = UsernameValidator.normalize(oldUsername);
      if (UsernameValidator.isValidFormat(normOld)) {
        debugPrint('Preserving existing username: $normOld for uid: $uid');
        await claimUsernameAtomic(
          uid: uid,
          newUsername: normOld,
        );
        return normOld;
      }
    }

    // 2. Generate base username from First Name & Last Name
    String base = UsernameValidator.generateBaseUsername(firstName, lastName);
    if (base.isEmpty) {
      base = 'user';
    }

    // 3. Atomically find and claim the first available candidate (base, base2, base3, ...)
    int counter = 1;
    const int maxAttempts = 100;

    while (counter <= maxAttempts) {
      final String candidate = counter == 1 ? base : '$base$counter';

      try {
        bool claimed = false;
        await _firestoreService.db.runTransaction((transaction) async {
          final newUsernameDocRef = _firestoreService.usernamesCollection.doc(candidate);
          final newUsernameSnap = await transaction.get(newUsernameDocRef);

          if (newUsernameSnap.exists) {
            final data = newUsernameSnap.data();
            final existingUid = data != null ? data['uid'] as String? : null;

            if (existingUid != null && existingUid != uid) {
              // Collision! Throw internal exception to abort transaction & try next counter
              throw UsernameTakenException('Collision on $candidate');
            }
          }

          // Claim the username document
          transaction.set(newUsernameDocRef, {
            'uid': uid,
            'username': candidate,
            'createdAt': FieldValue.serverTimestamp(),
          });

          // Update user document
          final userDocRef = _firestoreService.usersCollection.doc(uid);
          transaction.set(userDocRef, {
            'uid': uid,
            'username': candidate,
            'normalizedUsername': candidate,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

          claimed = true;
        });

        if (claimed) {
          debugPrint('SUCCESS: Atomically generated & claimed username "$candidate" for uid $uid');
          return candidate;
        }
      } on UsernameTakenException {
        // Candidate taken, increment counter and try candidate2, candidate3...
        counter++;
      } catch (e) {
        debugPrint('Error during auto-username generation transaction attempt for "$candidate": $e');
        rethrow;
      }
    }

    throw Exception('Failed to generate a unique username after $maxAttempts attempts.');
  }
}
