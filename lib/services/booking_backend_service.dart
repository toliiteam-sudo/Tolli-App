import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/booking_model.dart';
import '../models/venue_model.dart';

import '../models/coupon_model.dart';

class PreparePaymentResponse {
  final bool success;
  final String message;
  final String? bookingId;
  final String? razorpayOrderId;
  final int? amountPaise;
  final int? courtPricePaise;
  final int? discountPaise;
  final String? appliedCouponCode;
  final String? currency;
  final String? keyId;
  final int? holdExpiresAt;

  PreparePaymentResponse({
    required this.success,
    required this.message,
    this.bookingId,
    this.razorpayOrderId,
    this.amountPaise,
    this.courtPricePaise,
    this.discountPaise,
    this.appliedCouponCode,
    this.currency,
    this.keyId,
    this.holdExpiresAt,
  });
}

class ValidateCouponResponse {
  final bool success;
  final String message;
  final bool isEligible;
  final String? code;
  final String? title;
  final String? description;
  final int? discountPaise;
  final int? discountRupees;
  final int? courtPricePaise;
  final int? finalPayablePaise;

  ValidateCouponResponse({
    required this.success,
    required this.message,
    required this.isEligible,
    this.code,
    this.title,
    this.description,
    this.discountPaise,
    this.discountRupees,
    this.courtPricePaise,
    this.finalPayablePaise,
  });
}

class GetCouponsResponse {
  final bool success;
  final String message;
  final List<CouponModel> coupons;

  GetCouponsResponse({
    required this.success,
    required this.message,
    required this.coupons,
  });
}

class VerifyPaymentResponse {
  final bool success;
  final String message;
  final BookingModel? booking;

  VerifyPaymentResponse({
    required this.success,
    required this.message,
    this.booking,
  });
}

class CancelBookingResponse {
  final bool success;
  final String message;
  final int? refundAmountPaise;
  final String? refundStatus;

  CancelBookingResponse({
    required this.success,
    required this.message,
    this.refundAmountPaise,
    this.refundStatus,
  });
}

class BookingBackendService {
  static final BookingBackendService _instance = BookingBackendService._internal();
  factory BookingBackendService() => _instance;
  BookingBackendService._internal();

  static String baseUrl = 'http://127.0.0.1:3000';
  static final List<String> _candidateUrls = [
    'http://127.0.0.1:3000',
    'http://10.98.254.157:3000',
    'http://localhost:3000',
    'http://10.0.2.2:3000',
    'https://tolli-app.onrender.com',
  ];

  static void setBaseUrl(String url) {
    baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  Map<String, dynamic>? _tryParseJson(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  /// 1. Prepare payment & place temporary hold atomically on server
  Future<PreparePaymentResponse> preparePayment({
    required String userId,
    required VenueModel venue,
    required CourtModel court,
    required VenueSlotModel slot,
    required String sportId,
    required String sportName,
    String? couponCode,
  }) async {
    final payload = <String, dynamic>{
      'userId': userId,
      'venueId': venue.id,
      'venueName': venue.name,
      'venueAddress': venue.address,
      'venueImageAsset': venue.imageAssets.isNotEmpty ? venue.imageAssets.first : '',
      'courtId': court.id,
      'courtName': court.name,
      'slotId': slot.id,
      'sportId': sportId,
      'sportName': sportName,
      'bookingDate': slot.date,
      'startTime': slot.startTime,
      'endTime': slot.endTime,
      'startTimestampMs': slot.startTimestampMs,
      'endTimestampMs': slot.endTimestampMs,
      'durationMinutes': slot.durationMinutes,
      'pricePaise': slot.pricePaise,
      'hourlyRatePaise': court.hourlyRatePaise,
      'cancellationPolicySnapshot': venue.cancellationPolicy,
    };
    if (couponCode != null && couponCode.isNotEmpty) {
      payload['couponCode'] = couponCode;
    }
    final body = jsonEncode(payload);

    final headers = {'Content-Type': 'application/json'};

    // Build list of target URLs to try (current baseUrl first, then candidate fallbacks)
    final urlsToTry = <String>[baseUrl];
    for (final cand in _candidateUrls) {
      if (!urlsToTry.contains(cand)) {
        urlsToTry.add(cand);
      }
    }

    String? lastErrorMessage;
    int? lastStatusCode;

    for (final targetBase in urlsToTry) {
      try {
        final url = Uri.parse('$targetBase/api/bookings/prepare-payment');
        final response = await http
            .post(url, headers: headers, body: body)
            .timeout(const Duration(seconds: 8));

        lastStatusCode = response.statusCode;
        final data = _tryParseJson(response.body);

        if (response.statusCode == 200 || response.statusCode == 201) {
          if (data != null && data['bookingId'] != null) {
            baseUrl = targetBase;
            return PreparePaymentResponse(
              success: true,
              message: data['message'] as String? ?? 'Hold placed successfully',
              bookingId: data['bookingId'] as String?,
              razorpayOrderId: data['razorpayOrderId'] as String?,
              amountPaise: (data['amountPaise'] as num?)?.toInt(),
              courtPricePaise: (data['courtPricePaise'] as num?)?.toInt(),
              discountPaise: (data['discountPaise'] as num?)?.toInt(),
              appliedCouponCode: data['appliedCouponCode'] as String?,
              currency: data['currency'] as String? ?? 'INR',
              keyId: data['keyId'] as String?,
              holdExpiresAt: (data['holdExpiresAt'] as num?)?.toInt(),
            );
          }
        } else if (response.statusCode == 409) {
          return PreparePaymentResponse(
            success: false,
            message: data?['message'] as String? ?? 'This time slot is no longer available.',
          );
        } else if (response.statusCode == 400) {
          return PreparePaymentResponse(
            success: false,
            message: data?['message'] as String? ?? 'Invalid booking or coupon request.',
          );
        } else if (response.statusCode == 401 || response.statusCode == 403) {
          return PreparePaymentResponse(
            success: false,
            message: data?['message'] as String? ?? 'Authentication failed. Please sign in again.',
          );
        } else if (response.statusCode == 404) {
          lastErrorMessage = 'Booking service endpoint unavailable (HTTP 404). Deployed Render server needs backend update.';
        } else {
          lastErrorMessage = data?['message'] as String? ?? 'Server returned HTTP ${response.statusCode} placing slot hold.';
        }
      } on TimeoutException {
        lastErrorMessage = 'Server timeout while placing slot hold. Please try again.';
      } catch (e) {
        debugPrint('[BookingBackendService] preparePayment error connecting to $targetBase: $e');
        lastErrorMessage = 'Unable to connect to booking server ($targetBase).';
      }
    }

    return PreparePaymentResponse(
      success: false,
      message: lastErrorMessage ??
          (lastStatusCode != null
              ? 'Server returned HTTP $lastStatusCode placing slot hold.'
              : 'Unable to reach booking backend server. Check connection.'),
    );
  }

  /// 2. Verify Razorpay Payment Signature
  Future<VerifyPaymentResponse> verifyPayment({
    required String bookingId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) async {
    final body = jsonEncode({
      'bookingId': bookingId,
      'razorpayOrderId': razorpayOrderId,
      'razorpayPaymentId': razorpayPaymentId,
      'razorpaySignature': razorpaySignature,
    });
    final headers = {'Content-Type': 'application/json'};

    final urlsToTry = <String>[baseUrl];
    for (final cand in _candidateUrls) {
      if (!urlsToTry.contains(cand)) {
        urlsToTry.add(cand);
      }
    }

    String? lastErrorMessage;

    for (final targetBase in urlsToTry) {
      try {
        final url = Uri.parse('$targetBase/api/payments/verify');
        final response = await http
            .post(url, headers: headers, body: body)
            .timeout(const Duration(seconds: 15));

        final data = _tryParseJson(response.body);

        if (response.statusCode == 200 && data != null && data['success'] == true) {
          baseUrl = targetBase;
          final bookingMap = data['booking'] as Map<String, dynamic>?;
          final booking = bookingMap != null ? BookingModel.fromMap(bookingMap) : null;
          return VerifyPaymentResponse(
            success: true,
            message: data['message'] as String? ?? 'Payment verified & booking confirmed!',
            booking: booking,
          );
        } else if (data != null && data['message'] != null) {
          return VerifyPaymentResponse(
            success: false,
            message: data['message'] as String,
          );
        }
      } on TimeoutException {
        lastErrorMessage = 'Payment verification timed out. We are verifying with bank.';
      } catch (e) {
        debugPrint('[BookingBackendService] verifyPayment error for $targetBase: $e');
        lastErrorMessage = 'Could not connect to payment verification server.';
      }
    }

    return VerifyPaymentResponse(
      success: false,
      message: lastErrorMessage ?? 'Payment verification failed on server.',
    );
  }

  /// 3. Cancel Booking & Trigger Refund
  Future<CancelBookingResponse> cancelBooking({
    required String bookingId,
    required String userId,
  }) async {
    final body = jsonEncode({'userId': userId});
    final headers = {'Content-Type': 'application/json'};

    final urlsToTry = <String>[baseUrl];
    for (final cand in _candidateUrls) {
      if (!urlsToTry.contains(cand)) {
        urlsToTry.add(cand);
      }
    }

    String? lastErrorMessage;

    for (final targetBase in urlsToTry) {
      try {
        final url = Uri.parse('$targetBase/api/bookings/$bookingId/cancel');
        final response = await http
            .post(url, headers: headers, body: body)
            .timeout(const Duration(seconds: 15));

        final data = _tryParseJson(response.body);

        if (response.statusCode == 200 && data != null && data['success'] == true) {
          baseUrl = targetBase;
          return CancelBookingResponse(
            success: true,
            message: data['message'] as String? ?? 'Booking cancelled successfully',
            refundAmountPaise: (data['refundAmountPaise'] as num?)?.toInt(),
            refundStatus: data['refundStatus'] as String?,
          );
        } else if (data != null && data['message'] != null) {
          return CancelBookingResponse(
            success: false,
            message: data['message'] as String,
          );
        }
      } catch (e) {
        debugPrint('[BookingBackendService] cancelBooking error for $targetBase: $e');
        lastErrorMessage = 'Network error processing cancellation.';
      }
    }

    return CancelBookingResponse(
      success: false,
      message: lastErrorMessage ?? 'Cancellation failed on server.',
    );
  }

  /// 4. Release Hold on cancelled or failed payment
  Future<bool> releaseHold({
    required String bookingId,
  }) async {
    if (bookingId.isEmpty) return false;
    final body = jsonEncode({'bookingId': bookingId});
    final headers = {'Content-Type': 'application/json'};

    final urlsToTry = <String>[baseUrl];
    for (final cand in _candidateUrls) {
      if (!urlsToTry.contains(cand)) urlsToTry.add(cand);
    }

    for (final targetBase in urlsToTry) {
      try {
        final url = Uri.parse('$targetBase/api/bookings/$bookingId/release-hold');
        final response = await http
            .post(url, headers: headers, body: body)
            .timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          return true;
        }
      } catch (e) {
        debugPrint('[BookingBackendService] releaseHold error for $targetBase: $e');
      }
    }
    return false;
  }

  /// 5. Get list of available coupons with eligibility evaluated
  Future<GetCouponsResponse> getCoupons({
    required String userId,
    required String venueId,
    required String sportId,
    required int amountPaise,
  }) async {
    final queryParams = 'userId=$userId&venueId=$venueId&sportId=$sportId&amountPaise=$amountPaise';
    final urlsToTry = <String>[baseUrl];
    for (final cand in _candidateUrls) {
      if (!urlsToTry.contains(cand)) urlsToTry.add(cand);
    }

    for (final targetBase in urlsToTry) {
      try {
        final url = Uri.parse('$targetBase/api/coupons?$queryParams');
        final response = await http.get(url).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          final data = _tryParseJson(response.body);
          if (data != null && data['coupons'] is List) {
            final list = (data['coupons'] as List)
                .map((item) => CouponModel.fromJson(item as Map<String, dynamic>))
                .toList();
            return GetCouponsResponse(
              success: true,
              message: 'Coupons retrieved successfully.',
              coupons: list,
            );
          }
        }
      } catch (e) {
        debugPrint('[BookingBackendService] getCoupons error for $targetBase: $e');
      }
    }

    return GetCouponsResponse(
      success: false,
      message: 'Failed to retrieve available coupons.',
      coupons: const [],
    );
  }

  /// 6. Validate a coupon code on the server
  Future<ValidateCouponResponse> validateCoupon({
    required String code,
    required String userId,
    required String venueId,
    required String sportId,
    required int amountPaise,
    String? bookingDate,
  }) async {
    final payload = <String, dynamic>{
      'code': code.trim(),
      'userId': userId,
      'venueId': venueId,
      'sportId': sportId,
      'amountPaise': amountPaise,
    };
    if (bookingDate != null) {
      payload['bookingDate'] = bookingDate;
    }
    final body = jsonEncode(payload);
    final headers = {'Content-Type': 'application/json'};

    final urlsToTry = <String>[baseUrl];
    for (final cand in _candidateUrls) {
      if (!urlsToTry.contains(cand)) urlsToTry.add(cand);
    }

    String? errorMessage;
    for (final targetBase in urlsToTry) {
      try {
        final url = Uri.parse('$targetBase/api/coupons/validate');
        final response = await http
            .post(url, headers: headers, body: body)
            .timeout(const Duration(seconds: 5));
        final data = _tryParseJson(response.body);

        if (response.statusCode == 200 && data != null) {
          return ValidateCouponResponse(
            success: true,
            message: data['message'] as String? ?? 'Coupon applied successfully!',
            isEligible: data['isEligible'] as bool? ?? true,
            code: data['code'] as String?,
            title: data['title'] as String?,
            description: data['description'] as String?,
            discountPaise: (data['discountPaise'] as num?)?.toInt(),
            discountRupees: (data['discountRupees'] as num?)?.toInt(),
            courtPricePaise: (data['courtPricePaise'] as num?)?.toInt(),
            finalPayablePaise: (data['finalPayablePaise'] as num?)?.toInt(),
          );
        } else if (data != null && data['message'] != null) {
          return ValidateCouponResponse(
            success: false,
            message: data['message'] as String,
            isEligible: false,
          );
        }
      } catch (e) {
        debugPrint('[BookingBackendService] validateCoupon error for $targetBase: $e');
        errorMessage = 'Unable to validate coupon on server.';
      }
    }

    return ValidateCouponResponse(
      success: false,
      message: errorMessage ?? 'Failed to validate coupon with server.',
      isEligible: false,
    );
  }

  /// 7. Query authoritative slot availability (booked and active holds) from backend
  Future<List<Map<String, dynamic>>> getSlotAvailability({
    required String venueId,
    required String courtId,
    required String date,
  }) async {
    final query = 'courtId=$courtId&venueId=$venueId&date=$date';
    final urlsToTry = <String>[baseUrl];
    for (final cand in _candidateUrls) {
      if (!urlsToTry.contains(cand)) urlsToTry.add(cand);
    }

    for (final targetBase in urlsToTry) {
      try {
        final url = Uri.parse('$targetBase/api/bookings/availability?$query');
        final response = await http.get(url).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          final data = _tryParseJson(response.body);
          if (data != null && data['bookings'] is List) {
            return (data['bookings'] as List).cast<Map<String, dynamic>>();
          }
        }
      } catch (e) {
        debugPrint('[BookingBackendService] getSlotAvailability error for $targetBase: $e');
      }
    }
    return const [];
  }
}
