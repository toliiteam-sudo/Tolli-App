import 'package:cloud_firestore/cloud_firestore.dart';

enum BookingStatus {
  pending,
  held,
  confirmed,
  completed,
  cancelled,
  refundPending,
  refunded,
}

extension BookingStatusExtension on BookingStatus {
  String get value {
    switch (this) {
      case BookingStatus.pending:
        return 'PENDING';
      case BookingStatus.held:
        return 'HELD';
      case BookingStatus.confirmed:
        return 'CONFIRMED';
      case BookingStatus.completed:
        return 'COMPLETED';
      case BookingStatus.cancelled:
        return 'CANCELLED';
      case BookingStatus.refundPending:
        return 'REFUND_PENDING';
      case BookingStatus.refunded:
        return 'REFUNDED';
    }
  }

  static BookingStatus fromString(String val) {
    switch (val.toUpperCase()) {
      case 'HELD':
        return BookingStatus.held;
      case 'CONFIRMED':
        return BookingStatus.confirmed;
      case 'COMPLETED':
        return BookingStatus.completed;
      case 'CANCELLED':
        return BookingStatus.cancelled;
      case 'REFUND_PENDING':
        return BookingStatus.refundPending;
      case 'REFUNDED':
        return BookingStatus.refunded;
      case 'PENDING':
      default:
        return BookingStatus.pending;
    }
  }
}

class BookingModel {
  final String bookingId;
  final String userId;
  final String venueId;
  final String venueName;
  final String venueAddress;
  final String venueImageAsset;
  final String courtId;
  final String courtName;
  final String slotId;
  final String sportId;
  final String sportName;
  final String bookingDate; // YYYY-MM-DD
  final String startTime;
  final String endTime;
  final int startTimestamp;
  final int endTimestamp;
  final int durationMinutes;
  final int amountPaise;
  final int discountPaise;
  final int feePaise;
  final int finalAmountPaise;
  final String currency;
  final BookingStatus bookingStatus;
  final String paymentStatus;
  final String? paymentId;
  final String? razorpayOrderId;
  final String? razorpayPaymentId;
  final String? appliedCouponCode;
  final int? holdExpiresAt;
  final String cancellationPolicySnapshot;
  final String? createdGameId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BookingModel({
    required this.bookingId,
    required this.userId,
    required this.venueId,
    required this.venueName,
    required this.venueAddress,
    required this.venueImageAsset,
    required this.courtId,
    required this.courtName,
    required this.slotId,
    required this.sportId,
    required this.sportName,
    required this.bookingDate,
    required this.startTime,
    required this.endTime,
    required this.startTimestamp,
    required this.endTimestamp,
    required this.durationMinutes,
    required this.amountPaise,
    required this.discountPaise,
    required this.feePaise,
    required this.finalAmountPaise,
    this.currency = 'INR',
    required this.bookingStatus,
    this.paymentStatus = 'CREATED',
    this.paymentId,
    this.razorpayOrderId,
    this.razorpayPaymentId,
    this.appliedCouponCode,
    this.holdExpiresAt,
    required this.cancellationPolicySnapshot,
    this.createdGameId,
    required this.createdAt,
    required this.updatedAt,
  });

  double get finalAmountRupees => finalAmountPaise / 100.0;
  double get baseAmountRupees => amountPaise / 100.0;
  double get feeRupees => feePaise / 100.0;
  double get discountRupees => discountPaise / 100.0;

  Map<String, dynamic> toMap() {
    return {
      'bookingId': bookingId,
      'userId': userId,
      'venueId': venueId,
      'venueName': venueName,
      'venueAddress': venueAddress,
      'venueImageAsset': venueImageAsset,
      'courtId': courtId,
      'courtName': courtName,
      'slotId': slotId,
      'sportId': sportId,
      'sportName': sportName,
      'bookingDate': bookingDate,
      'startTime': startTime,
      'endTime': endTime,
      'startTimestamp': startTimestamp,
      'endTimestamp': endTimestamp,
      'durationMinutes': durationMinutes,
      'amountPaise': amountPaise,
      'discountPaise': discountPaise,
      'feePaise': feePaise,
      'finalAmountPaise': finalAmountPaise,
      'currency': currency,
      'bookingStatus': bookingStatus.value,
      'paymentStatus': paymentStatus,
      'paymentId': paymentId,
      'razorpayOrderId': razorpayOrderId,
      'razorpayPaymentId': razorpayPaymentId,
      'appliedCouponCode': appliedCouponCode,
      'holdExpiresAt': holdExpiresAt,
      'cancellationPolicySnapshot': cancellationPolicySnapshot,
      'createdGameId': createdGameId,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory BookingModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return BookingModel(
      bookingId: docId ?? map['bookingId'] ?? '',
      userId: map['userId'] ?? '',
      venueId: map['venueId'] ?? '',
      venueName: map['venueName'] ?? '',
      venueAddress: map['venueAddress'] ?? '',
      venueImageAsset: map['venueImageAsset'] ?? '',
      courtId: map['courtId'] ?? '',
      courtName: map['courtName'] ?? '',
      slotId: map['slotId'] ?? '',
      sportId: map['sportId'] ?? '',
      sportName: map['sportName'] ?? '',
      bookingDate: map['bookingDate'] ?? '',
      startTime: map['startTime'] ?? '',
      endTime: map['endTime'] ?? '',
      startTimestamp: (map['startTimestamp'] as num?)?.toInt() ?? 0,
      endTimestamp: (map['endTimestamp'] as num?)?.toInt() ?? 0,
      durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 60,
      amountPaise: (map['amountPaise'] as num?)?.toInt() ?? 0,
      discountPaise: (map['discountPaise'] as num?)?.toInt() ?? 0,
      feePaise: (map['feePaise'] as num?)?.toInt() ?? 0,
      finalAmountPaise: (map['finalAmountPaise'] as num?)?.toInt() ?? 0,
      currency: map['currency'] ?? 'INR',
      bookingStatus: BookingStatusExtension.fromString(map['bookingStatus'] ?? 'PENDING'),
      paymentStatus: map['paymentStatus'] ?? 'CREATED',
      paymentId: map['paymentId'],
      razorpayOrderId: map['razorpayOrderId'],
      razorpayPaymentId: map['razorpayPaymentId'],
      appliedCouponCode: map['appliedCouponCode'] as String?,
      holdExpiresAt: (map['holdExpiresAt'] as num?)?.toInt(),
      cancellationPolicySnapshot: map['cancellationPolicySnapshot'] ?? 'Standard policy',
      createdGameId: map['createdGameId'],
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }

  factory BookingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return BookingModel.fromMap(data, doc.id);
  }
}
