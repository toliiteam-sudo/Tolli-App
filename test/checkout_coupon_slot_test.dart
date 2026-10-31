import 'package:flutter_test/flutter_test.dart';
import 'package:tolii/models/coupon_model.dart';
import 'package:tolii/models/booking_model.dart';
import 'package:tolii/services/booking_backend_service.dart';
import 'package:tolii/utils/booking_time_utils.dart';

void main() {
  group('Coupon Model & Validation Unit Tests', () {
    test('CouponModel parsing and computed discount badge for fixed coupon', () {
      final flatCouponJson = {
        'code': 'TOLII150',
        'title': 'Flat ₹150 Off',
        'description': 'Enjoy ₹150 off on all court bookings above ₹500',
        'discountType': 'FIXED_PAISE',
        'discountValue': 15000,
        'minBookingPaise': 50000,
        'maxDiscountPaise': 15000,
        'isEligible': true,
        'discountPaise': 15000,
        'discountRupees': 150,
        'ineligibilityReason': null,
      };

      final coupon = CouponModel.fromJson(flatCouponJson);
      expect(coupon.code, 'TOLII150');
      expect(coupon.discountType, 'FIXED_PAISE');
      expect(coupon.discountValue, 15000);
      expect(coupon.discountRupees, 150);
      expect(coupon.discountBadgeText, '₹150 OFF');
      expect(coupon.minBookingPaise, 50000);
      expect(coupon.isEligible, true);
    });

    test('Percentage coupon badge and discount calculation', () {
      final pctCouponJson = {
        'code': 'PLAYSPORTS20',
        'title': '20% Mega Sports Savings',
        'description': '20% off on all sports up to ₹250',
        'discountType': 'PERCENTAGE',
        'discountValue': 20,
        'maxDiscountPaise': 25000,
        'minBookingPaise': 60000,
        'isEligible': true,
        'discountPaise': 16000,
        'discountRupees': 160,
      };

      final coupon = CouponModel.fromJson(pctCouponJson);
      expect(coupon.discountType, 'PERCENTAGE');
      expect(coupon.discountValue, 20);
      expect(coupon.discountBadgeText, '20% OFF');
      expect(coupon.maxDiscountPaise, 25000);

      // On a ₹800 (80,000 paise) booking: 20% = 16,000 paise (₹160), capped at ₹250 (25000 paise)
      final calculatedDiscountPaise = ((80000 * coupon.discountValue) ~/ 100);
      expect(calculatedDiscountPaise, 16000);
      expect(calculatedDiscountPaise <= coupon.maxDiscountPaise, true);
    });

    test('Ineligible coupon parsing with reason', () {
      final ineligibleJson = {
        'code': 'CRICKET100',
        'title': 'Cricket Super Saver',
        'description': '₹100 off on Box Cricket bookings above ₹700',
        'discountType': 'FIXED_PAISE',
        'discountValue': 10000,
        'minBookingPaise': 70000,
        'maxDiscountPaise': 10000,
        'isEligible': false,
        'ineligibilityReason': 'Minimum booking amount of ₹700 required',
      };

      final coupon = CouponModel.fromJson(ineligibleJson);
      expect(coupon.isEligible, false);
      expect(coupon.ineligibilityReason, 'Minimum booking amount of ₹700 required');
    });

    test('PreparePaymentResponse handles coupon fields and discount breakdown', () {
      final resp = PreparePaymentResponse(
        success: true,
        message: 'Order created',
        bookingId: 'bk_test_123',
        razorpayOrderId: 'order_test_456',
        amountPaise: 65000, // Discounted final payable (₹650)
        courtPricePaise: 80000, // Original court price (₹800)
        discountPaise: 15000,   // Discount (₹150)
        appliedCouponCode: 'TOLII150',
        currency: 'INR',
        keyId: 'rzp_test_public_key',
      );

      expect(resp.success, true);
      expect(resp.bookingId, 'bk_test_123');
      expect(resp.razorpayOrderId, 'order_test_456');
      expect(resp.amountPaise, 65000);
      expect(resp.courtPricePaise, 80000);
      expect(resp.discountPaise, 15000);
      expect(resp.appliedCouponCode, 'TOLII150');

      // Verify price breakdown math: courtPrice - discount = final payable
      expect(resp.courtPricePaise! - resp.discountPaise!, resp.amountPaise);
    });

    test('BookingModel serializes and deserializes appliedCouponCode', () {
      final now = DateTime.now();
      final booking = BookingModel(
        bookingId: 'bk_coupon_test',
        userId: 'user_1',
        venueId: 'venue_sidsar_arena',
        venueName: 'Sidsar Sports Arena',
        venueAddress: 'Sidsar Road, Bhavnagar',
        venueImageAsset: 'assets/images/venue_1.jpg',
        courtId: 'court_sidsar_cricket_1',
        courtName: 'Box Cricket Arena 1',
        slotId: 'slot_composite_1',
        sportId: 'cricket',
        sportName: 'Box Cricket',
        bookingDate: '2026-10-30',
        startTime: '04:00 PM',
        endTime: '05:00 PM',
        startTimestamp: now.millisecondsSinceEpoch,
        endTimestamp: now.millisecondsSinceEpoch + 3600000,
        durationMinutes: 60,
        amountPaise: 80000,
        discountPaise: 15000,
        feePaise: 0,
        finalAmountPaise: 65000,
        bookingStatus: BookingStatus.confirmed,
        paymentStatus: 'PAID',
        cancellationPolicySnapshot: 'Free cancellation up to 2 hours prior',
        createdAt: now,
        updatedAt: now,
        appliedCouponCode: 'TOLII150',
      );

      final map = booking.toMap();
      expect(map['appliedCouponCode'], 'TOLII150');
      expect(map['finalAmountPaise'], 65000);
      expect(map['discountPaise'], 15000);

      final reconstructed = BookingModel.fromMap(map, 'bk_coupon_test');
      expect(reconstructed.appliedCouponCode, 'TOLII150');
      expect(reconstructed.finalAmountPaise, 65000);
      expect(reconstructed.discountPaise, 15000);
      expect(reconstructed.amountPaise, 80000);
      expect(reconstructed.finalAmountRupees, 650.0);
      expect(reconstructed.discountRupees, 150.0);
    });
  });

  group('Slot Availability and Overlap Validation Tests', () {
    test('Overlapping intervals detection for confirmed bookings', () {
      // 04:00 PM to 05:00 PM
      final start1 = BookingTimeUtils.parseTimeToMinutes('04:00 PM');
      final end1 = BookingTimeUtils.parseTimeToMinutes('05:00 PM');

      // Test partial overlap: 04:30 PM to 05:30 PM
      final start2 = BookingTimeUtils.parseTimeToMinutes('04:30 PM');
      final end2 = BookingTimeUtils.parseTimeToMinutes('05:30 PM');

      final overlaps = (start1 < end2) && (end1 > start2);
      expect(overlaps, true);

      // Test non-overlapping contiguous interval: 05:00 PM to 06:00 PM
      final start3 = BookingTimeUtils.parseTimeToMinutes('05:00 PM');
      final end3 = BookingTimeUtils.parseTimeToMinutes('06:00 PM');

      final overlapsContiguous = (start1 < end3) && (end1 > start3);
      expect(overlapsContiguous, false);

      // Test completely separate interval: 06:00 PM to 07:00 PM
      final start4 = BookingTimeUtils.parseTimeToMinutes('06:00 PM');
      final end4 = BookingTimeUtils.parseTimeToMinutes('07:00 PM');

      final overlapsSeparate = (start1 < end4) && (end1 > start4);
      expect(overlapsSeparate, false);
    });
  });
}
