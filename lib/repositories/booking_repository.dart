import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/booking_model.dart';

class BookingRepository {
  static final BookingRepository _instance = BookingRepository._internal();
  factory BookingRepository() => _instance;
  BookingRepository._internal();

  FirebaseFirestore? _firestoreInstance;
  FirebaseFirestore? get _firestore {
    try {
      _firestoreInstance ??= FirebaseFirestore.instance;
      return _firestoreInstance;
    } catch (_) {
      return null;
    }
  }

  /// Stream user's bookings sorted by creation date descending
  Stream<List<BookingModel>> streamUserBookings(String userId) {
    if (userId.isEmpty || _firestore == null) {
      return Stream.value([]);
    }

    try {
      return _firestore!
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .snapshots()
          .map((snapshot) {
        final docs = snapshot.docs.map((doc) => BookingModel.fromFirestore(doc)).toList();
        docs.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return docs;
      }).handleError((err) {
        debugPrint('[BookingRepository] Error streaming bookings for $userId: $err');
        return <BookingModel>[];
      });
    } catch (e) {
      debugPrint('[BookingRepository] Firebase uninitialized: $e');
      return Stream.value(<BookingModel>[]);
    }
  }

  /// Get booking by ID
  Future<BookingModel?> getBookingById(String bookingId) async {
    try {
      if (_firestore != null) {
        final doc = await _firestore!.collection('bookings').doc(bookingId).get();
        if (doc.exists) {
          return BookingModel.fromFirestore(doc);
        }
      }
    } catch (e) {
      debugPrint('[BookingRepository] Error getting booking $bookingId: $e');
    }
    return null;
  }

  /// Link a created game activity ID to an existing confirmed booking
  Future<void> linkGameToBooking(String bookingId, String gameId) async {
    try {
      if (_firestore != null) {
        await _firestore!.collection('bookings').doc(bookingId).update({
          'createdGameId': gameId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('[BookingRepository] Error linking game $gameId to booking $bookingId: $e');
    }
  }
}
