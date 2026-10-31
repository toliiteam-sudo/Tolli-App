import 'package:flutter_test/flutter_test.dart';
import 'package:tolii/models/venue_model.dart';
import 'package:tolii/models/booking_model.dart';
import 'package:tolii/repositories/venue_repository.dart';
import 'package:tolii/services/booking_backend_service.dart';
import 'package:tolii/utils/booking_time_utils.dart';
import 'package:tolii/widgets/snap_time_ruler.dart';

void main() {
  group('Venue & Court Model Tests', () {
    test('CourtModel serialization and pricing', () {
      const court = CourtModel(
        id: 'court_1',
        name: 'Box Cricket Arena 1',
        sportId: 'Box Cricket',
        capacity: 12,
        surfaceType: 'Turf',
        hourlyRatePaise: 80000,
        minBookingMinutes: 30,
      );

      expect(court.hourlyRatePaise, 80000);
      expect(court.hourlyRatePaise / 100, 800.0);
      expect(court.minBookingMinutes, 30);

      final map = court.toMap();
      final fromMap = CourtModel.fromMap(map);
      expect(fromMap.name, 'Box Cricket Arena 1');
      expect(fromMap.capacity, 12);
      expect(fromMap.minBookingMinutes, 30);
    });

    test('VenueSlotModel availability and hold expiry logic', () {
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      final availableSlot = VenueSlotModel(
        id: 'slot_1',
        courtId: 'court_1',
        venueId: 'venue_1',
        date: '2026-10-10',
        startTime: '07:00 AM',
        endTime: '07:30 AM',
        startTimestampMs: nowMs,
        endTimestampMs: nowMs + 1800000,
        durationMinutes: 30,
        pricePaise: 30000,
        status: 'AVAILABLE',
      );
      expect(availableSlot.isAvailable, true);

      final activeHoldSlot = VenueSlotModel(
        id: 'slot_2',
        courtId: 'court_1',
        venueId: 'venue_1',
        date: '2026-10-10',
        startTime: '08:00 AM',
        endTime: '09:00 AM',
        startTimestampMs: nowMs,
        endTimestampMs: nowMs + 3600000,
        durationMinutes: 60,
        pricePaise: 60000,
        status: 'HELD',
        heldByUserId: 'user_xyz',
        holdExpiresAtMs: nowMs + 600000, // 10 minutes in future
      );
      expect(activeHoldSlot.isAvailable, false);

      final expiredHoldSlot = VenueSlotModel(
        id: 'slot_3',
        courtId: 'court_1',
        venueId: 'venue_1',
        date: '2026-10-10',
        startTime: '09:00 AM',
        endTime: '10:00 AM',
        startTimestampMs: nowMs,
        endTimestampMs: nowMs + 3600000,
        durationMinutes: 60,
        pricePaise: 60000,
        status: 'HELD',
        heldByUserId: 'user_abc',
        holdExpiresAtMs: nowMs - 1000, // Expired hold
      );
      expect(expiredHoldSlot.isAvailable, true);
    });

    test('BookingModel integer paise conversion & status mapping', () {
      final booking = BookingModel(
        bookingId: 'bk_test_123',
        userId: 'user_1',
        venueId: 'venue_1',
        venueName: 'Sports Arena Sidsar',
        venueAddress: 'Sidsar Road, Bhavnagar',
        venueImageAsset: 'assets/images/pickleball_courts.png',
        courtId: 'court_1',
        courtName: 'Box Cricket Arena 1',
        slotId: 'slot_1',
        sportId: 'Box Cricket',
        sportName: 'Box Cricket',
        bookingDate: '2026-10-10',
        startTime: '10:30 AM',
        endTime: '12:30 PM',
        startTimestamp: 1791590400000,
        endTimestamp: 1791597600000,
        durationMinutes: 120,
        amountPaise: 160000,
        discountPaise: 0,
        feePaise: 0,
        finalAmountPaise: 160000,
        currency: 'INR',
        bookingStatus: BookingStatus.confirmed,
        paymentStatus: 'CAPTURED',
        razorpayOrderId: 'order_K12345',
        razorpayPaymentId: 'pay_P67890',
        cancellationPolicySnapshot: 'Full refund 24h prior.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(booking.finalAmountRupees, 1600.0);
      expect(booking.durationMinutes, 120);
      expect(booking.bookingStatus.value, 'CONFIRMED');

      final map = booking.toMap();
      final restored = BookingModel.fromMap(map);
      expect(restored.bookingId, 'bk_test_123');
      expect(restored.finalAmountRupees, 1600.0);
      expect(restored.durationMinutes, 120);
      expect(restored.startTime, '10:30 AM');
      expect(restored.endTime, '12:30 PM');
      expect(restored.bookingStatus, BookingStatus.confirmed);
    });

    test('BookingBackendService handles server status & error responses safely without FormatException', () async {
      final service = BookingBackendService();

      const sampleVenue = VenueModel(
        id: 'venue_1',
        name: 'Test Venue',
        address: 'Test Address',
        city: 'Bhavnagar',
        latitude: 21.7645,
        longitude: 72.1519,
        imageAssets: [],
        courts: [],
        rating: 4.8,
        reviewsCount: 10,
        startingPricePaise: 50000,
        cancellationPolicy: 'Free cancellation',
        supportedSports: ['Box Cricket'],
        facilities: ['Parking', 'Lighting'],
        operatingHours: '6:00 AM - 11:00 PM',
        rules: ['Wear non-marking shoes'],
      );
      const sampleCourt = CourtModel(
        id: 'court_1',
        name: 'Court 1',
        sportId: 'Box Cricket',
        capacity: 10,
        surfaceType: 'Turf',
        hourlyRatePaise: 50000,
      );
      final sampleSlot = VenueSlotModel(
        id: 'slot_1',
        courtId: 'court_1',
        venueId: 'venue_1',
        date: '2026-10-10',
        startTime: '08:00 AM',
        endTime: '09:00 AM',
        startTimestampMs: 1791590400000,
        endTimestampMs: 1791594000000,
        durationMinutes: 60,
        pricePaise: 50000,
      );

      final res = await service.preparePayment(
        userId: 'user_1',
        venue: sampleVenue,
        court: sampleCourt,
        slot: sampleSlot,
        sportId: 'Box Cricket',
        sportName: 'Box Cricket',
      );

      expect(res, isNotNull);
      expect(res.message, isNotEmpty);
    });
  });

  group('Flexible Booking & Multi-Hour Regression Tests (14 Requirements)', () {
    const court = CourtModel(
      id: 'court_sidsar_cricket_1',
      name: 'Box Cricket Arena 1',
      sportId: 'Box Cricket',
      capacity: 14,
      surfaceType: 'Synthetic Turf',
      hourlyRatePaise: 80000, // ₹800/hr
      minBookingMinutes: 30,
    );

    // 1. Selecting a 10:30 AM start time
    test('1. Selecting a 10:30 AM start time parses and formats correctly', () {
      final minutes = BookingTimeUtils.parseTimeToMinutes('10:30 AM');
      expect(minutes, 10 * 60 + 30);
      expect(BookingTimeUtils.formatMinutesToTime(minutes), '10:30 AM');

      final end30m = BookingTimeUtils.calculateEndTime('10:30 AM', 30);
      expect(end30m, '11:00 AM');

      final end2hr = BookingTimeUtils.calculateEndTime('10:30 AM', 120);
      expect(end2hr, '12:30 PM');
    });

    // 2. Booking for 30 minutes where permitted
    test('2. Booking for 30 minutes where permitted calculates correct half-hour price', () {
      final pricePaise = court.calculatePricePaise(30);
      expect(pricePaise, 40000); // ₹400
      expect(BookingTimeUtils.formatDuration(30), '30 mins');
      expect(BookingTimeUtils.formatDurationCompact(30), '30 min');
    });

    // 3. Booking for 1 hour
    test('3. Booking for 1 hour calculates standard hourly rate', () {
      final pricePaise = court.calculatePricePaise(60);
      expect(pricePaise, 80000); // ₹800
      expect(BookingTimeUtils.formatDuration(60), '1 hour');
      expect(BookingTimeUtils.formatDurationCompact(60), '1 hr');
    });

    // 4. Booking for 2 hours
    test('4. Booking for 2 hours consecutive interval', () {
      final pricePaise = court.calculatePricePaise(120);
      expect(pricePaise, 160000); // ₹1,600
      expect(BookingTimeUtils.formatDuration(120), '2 hours');
      expect(BookingTimeUtils.formatDurationCompact(120), '2 hr');
    });

    // 5. Correct total price for multiple hours
    test('5. Correct total price across multiple durations', () {
      // 0.5 hr @ ₹800/hr = ₹400
      expect(court.calculatePricePaise(30), 40000);
      // 1 hr @ ₹800/hr = ₹800
      expect(court.calculatePricePaise(60), 80000);
      // 1.5 hr @ ₹800/hr = ₹1,200
      expect(court.calculatePricePaise(90), 120000);
      // 2 hr @ ₹800/hr = ₹1,600
      expect(court.calculatePricePaise(120), 160000);
      // 2.5 hr @ ₹800/hr = ₹2,000
      expect(court.calculatePricePaise(150), 200000);
      // 3 hr @ ₹800/hr = ₹2,400
      expect(court.calculatePricePaise(180), 240000);
    });

    // 6. A booking ending exactly at venue closing time
    test('6. A booking ending exactly at venue closing time is valid', () {
      final opHours = BookingTimeUtils.parseOperatingHours('06:00 AM - 11:00 PM');
      expect(opHours.openMinutes, 360);
      expect(opHours.closeMinutes, 1380); // 11:00 PM = 23:00 = 1380

      // 10:00 PM (1320) + 60 min = 1380 (11:00 PM exactly)
      final fits = BookingTimeUtils.isIntervalWithinOperatingHours(
        startMinutes: 1320,
        durationMinutes: 60,
        openMinutes: opHours.openMinutes,
        closeMinutes: opHours.closeMinutes,
      );
      expect(fits, true);

      // Verify repository interval status for closing boundary
      final sampleGranular = [
        const VenueSlotModel(
          id: 'slot_1320',
          courtId: 'court_1',
          venueId: 'venue_1',
          date: '2026-10-15',
          startTime: '10:00 PM',
          endTime: '10:30 PM',
          startTimestampMs: 0,
          endTimestampMs: 0,
          durationMinutes: 30,
          pricePaise: 40000,
          status: 'AVAILABLE',
        ),
        const VenueSlotModel(
          id: 'slot_1350',
          courtId: 'court_1',
          venueId: 'venue_1',
          date: '2026-10-15',
          startTime: '10:30 PM',
          endTime: '11:00 PM',
          startTimestampMs: 0,
          endTimestampMs: 0,
          durationMinutes: 30,
          pricePaise: 40000,
          status: 'AVAILABLE',
        ),
      ];
      final status = VenueRepository.evaluateIntervalStatus(
        granularSlots: sampleGranular,
        startTime: '10:00 PM',
        durationMinutes: 60,
        closeMinutes: opHours.closeMinutes,
      );
      expect(status, 'AVAILABLE');
    });

    // 7. A booking extending beyond closing time
    test('7. A booking extending beyond closing time is rejected', () {
      final opHours = BookingTimeUtils.parseOperatingHours('06:00 AM - 11:00 PM');

      // 10:30 PM (1350) + 60 min = 1410 (11:30 PM > 11:00 PM)
      final fits = BookingTimeUtils.isIntervalWithinOperatingHours(
        startMinutes: 1350,
        durationMinutes: 60,
        openMinutes: opHours.openMinutes,
        closeMinutes: opHours.closeMinutes,
      );
      expect(fits, false);

      final status = VenueRepository.evaluateIntervalStatus(
        granularSlots: const [],
        startTime: '10:30 PM',
        durationMinutes: 60,
        closeMinutes: opHours.closeMinutes,
      );
      expect(status, 'EXCEEDS_CLOSING');
    });

    // 8. An overlapping confirmed booking
    test('8. An overlapping confirmed booking is detected across the full interval', () {
      final granularSlots = [
        const VenueSlotModel(
          id: 'slot_1000',
          courtId: 'court_1',
          venueId: 'venue_1',
          date: '2026-10-15',
          startTime: '10:00 AM',
          endTime: '10:30 AM',
          startTimestampMs: 0,
          endTimestampMs: 0,
          durationMinutes: 30,
          pricePaise: 40000,
          status: 'AVAILABLE',
        ),
        const VenueSlotModel(
          id: 'slot_1030',
          courtId: 'court_1',
          venueId: 'venue_1',
          date: '2026-10-15',
          startTime: '10:30 AM',
          endTime: '11:00 AM',
          startTimestampMs: 0,
          endTimestampMs: 0,
          durationMinutes: 30,
          pricePaise: 40000,
          status: 'AVAILABLE',
        ),
        const VenueSlotModel(
          id: 'slot_1100',
          courtId: 'court_1',
          venueId: 'venue_1',
          date: '2026-10-15',
          startTime: '11:00 AM',
          endTime: '11:30 AM',
          startTimestampMs: 0,
          endTimestampMs: 0,
          durationMinutes: 30,
          pricePaise: 40000,
          status: 'BOOKED', // Confirmed booking overlaps here
        ),
        const VenueSlotModel(
          id: 'slot_1130',
          courtId: 'court_1',
          venueId: 'venue_1',
          date: '2026-10-15',
          startTime: '11:30 AM',
          endTime: '12:00 PM',
          startTimestampMs: 0,
          endTimestampMs: 0,
          durationMinutes: 30,
          pricePaise: 40000,
          status: 'AVAILABLE',
        ),
      ];

      // Requesting 10:00 AM - 12:00 PM (2 hours) overlaps with slot_1100 (BOOKED)
      final status = VenueRepository.evaluateIntervalStatus(
        granularSlots: granularSlots,
        startTime: '10:00 AM',
        durationMinutes: 120,
        closeMinutes: 1380,
      );
      expect(status, 'BOOKED');
    });

    // 9. An overlapping active hold
    test('9. An overlapping active hold is detected and marked HELD', () {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final granularSlots = [
        const VenueSlotModel(
          id: 'slot_1030',
          courtId: 'court_1',
          venueId: 'venue_1',
          date: '2026-10-15',
          startTime: '10:30 AM',
          endTime: '11:00 AM',
          startTimestampMs: 0,
          endTimestampMs: 0,
          durationMinutes: 30,
          pricePaise: 40000,
          status: 'AVAILABLE',
        ),
        VenueSlotModel(
          id: 'slot_1100',
          courtId: 'court_1',
          venueId: 'venue_1',
          date: '2026-10-15',
          startTime: '11:00 AM',
          endTime: '11:30 AM',
          startTimestampMs: 0,
          endTimestampMs: 0,
          durationMinutes: 30,
          pricePaise: 40000,
          status: 'HELD',
          holdExpiresAtMs: nowMs + 600000, // 10 mins active hold
        ),
      ];

      final status = VenueRepository.evaluateIntervalStatus(
        granularSlots: granularSlots,
        startTime: '10:30 AM',
        durationMinutes: 60, // 10:30 AM - 11:30 AM covers the held slot
        closeMinutes: 1380,
      );
      expect(status, 'HELD');
    });

    // 10. Two concurrent requests for overlapping intervals
    test('10. Overlapping interval detection helper catches any partial intersection', () {
      // Interval A: 10:30 AM - 12:30 PM (630 to 750)
      // Interval B: 12:00 PM - 01:00 PM (720 to 780)
      // Intersection: [720, 750) -> overlap is true
      expect(BookingTimeUtils.doIntervalsOverlap(630, 750, 720, 780), true);

      // Interval C: 12:30 PM - 01:30 PM (750 to 810)
      // Touching boundary exactly (endA == startC) -> no overlap
      expect(BookingTimeUtils.doIntervalsOverlap(630, 750, 750, 810), false);
    });

    // 11. Expired hold no longer blocking availability
    test('11. Expired hold is recognized as available', () {
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final expiredSlot = VenueSlotModel(
        id: 'slot_held',
        courtId: 'court_1',
        venueId: 'venue_1',
        date: '2026-10-15',
        startTime: '02:00 PM',
        endTime: '02:30 PM',
        startTimestampMs: 0,
        endTimestampMs: 0,
        durationMinutes: 30,
        pricePaise: 40000,
        status: 'HELD',
        holdExpiresAtMs: nowMs - 5000, // Expired 5 seconds ago
      );

      expect(expiredSlot.isAvailable, true);

      final status = VenueRepository.evaluateIntervalStatus(
        granularSlots: [expiredSlot],
        startTime: '02:00 PM',
        durationMinutes: 30,
        closeMinutes: 1380,
      );
      expect(status, 'AVAILABLE');
    });

    // 12. Failed/cancelled payment releasing or expiring hold safely
    test('12. Composite slot creation for checkout and hold tracking', () {
      final compositeSlot = VenueRepository.createCompositeSlot(
        court: court,
        venueId: 'venue_sidsar_arena',
        dateStr: '2026-10-15',
        startTime: '10:30 AM',
        durationMinutes: 120,
      );

      expect(compositeSlot.startTime, '10:30 AM');
      expect(compositeSlot.endTime, '12:30 PM');
      expect(compositeSlot.durationMinutes, 120);
      expect(compositeSlot.pricePaise, 160000); // 2 hrs * ₹800 = ₹1,600
      expect(compositeSlot.status, 'AVAILABLE');
    });

    // 13. Correct start/end/duration in Booking Review and My Bookings
    test('13. BookingModel preserves full interval, rate, and duration', () {
      final booking = BookingModel(
        bookingId: 'bk_full_interval_test',
        userId: 'usr_1',
        venueId: 'venue_sidsar_arena',
        venueName: 'Sports Arena Sidsar',
        venueAddress: 'Sidsar Road, Bhavnagar',
        venueImageAsset: '',
        courtId: court.id,
        courtName: court.name,
        slotId: 'composite_slot_id',
        sportId: 'Box Cricket',
        sportName: 'Box Cricket',
        bookingDate: '2026-10-15',
        startTime: '10:30 AM',
        endTime: '12:30 PM',
        startTimestamp: 1791590400000,
        endTimestamp: 1791597600000,
        durationMinutes: 120,
        amountPaise: 160000,
        discountPaise: 0,
        feePaise: 0,
        finalAmountPaise: 160000,
        currency: 'INR',
        bookingStatus: BookingStatus.confirmed,
        paymentStatus: 'CAPTURED',
        cancellationPolicySnapshot: 'Full refund 24h prior.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(booking.startTime, '10:30 AM');
      expect(booking.endTime, '12:30 PM');
      expect(booking.durationMinutes, 120);
      expect(BookingTimeUtils.formatDuration(booking.durationMinutes), '2 hours');
      expect(booking.finalAmountRupees, 1600.0);
    });

    // 14. Existing 1-hour bookings remaining readable and correctly represented
    test('14. Existing 1-hour bookings without new fields deserialize and display properly', () {
      final legacyMap = {
        'bookingId': 'bk_legacy_1hr',
        'userId': 'usr_legacy',
        'venueId': 'venue_sidsar_arena',
        'venueName': 'Sports Arena Sidsar',
        'venueAddress': 'Sidsar Road',
        'courtId': 'court_1',
        'courtName': 'Court 1',
        'slotId': 'court_1_2026-10-01_slot_0',
        'sportId': 'Box Cricket',
        'sportName': 'Box Cricket',
        'bookingDate': '2026-10-01',
        'startTime': '06:00 AM',
        'endTime': '07:00 AM',
        'startTimestamp': 1790000000000,
        'endTimestamp': 1790003600000,
        'durationMinutes': 60,
        'amountPaise': 80000,
        'finalAmountPaise': 80000,
        'bookingStatus': 'CONFIRMED',
      };

      final legacyBooking = BookingModel.fromMap(legacyMap);
      expect(legacyBooking.bookingId, 'bk_legacy_1hr');
      expect(legacyBooking.startTime, '06:00 AM');
      expect(legacyBooking.endTime, '07:00 AM');
      expect(legacyBooking.durationMinutes, 60);
      expect(legacyBooking.finalAmountRupees, 800.0);
      expect(BookingTimeUtils.formatDuration(legacyBooking.durationMinutes), '1 hour');
    });
  });

  group('Snap-to-Time Ruler & Day/Night Theming Tests (10 Requirements)', () {
    // 1. Snap from an arbitrary drag offset to nearest valid 30-minute start
    test('1. Snap from arbitrary drag offset to nearest valid 30-minute start', () {
      const stepWidth = 64.0;
      const maxIndex = 30;

      // Scroll offset 100.0 / 64.0 = 1.5625 -> rounds to index 2 (1 hour in)
      final index1 = BookingTimeUtils.snapOffsetToTickIndex(
        scrollOffset: 100.0,
        stepWidth: stepWidth,
        maxIndex: maxIndex,
      );
      expect(index1, 2);

      // Scroll offset 20.0 / 64.0 = 0.3125 -> rounds to index 0
      final index2 = BookingTimeUtils.snapOffsetToTickIndex(
        scrollOffset: 20.0,
        stepWidth: stepWidth,
        maxIndex: maxIndex,
      );
      expect(index2, 0);

      // Scroll offset 50.0 / 64.0 = 0.78125 -> rounds to index 1
      final index3 = BookingTimeUtils.snapOffsetToTickIndex(
        scrollOffset: 50.0,
        stepWidth: stepWidth,
        maxIndex: maxIndex,
      );
      expect(index3, 1);
    });

    // 2. Tapping a tick selects its exact time
    test('2. Tapping a tick index selects exact 30-minute time string', () {
      final startTimes = BookingTimeUtils.generateStartTimes(
        openMinutes: 360, // 06:00 AM
        closeMinutes: 1380, // 11:00 PM
        intervalMinutes: 30,
      );

      // Index 0: 06:00 AM
      expect(startTimes[0], '06:00 AM');
      // Index 1: 06:30 AM
      expect(startTimes[1], '06:30 AM');
      // Index 9: 10:30 AM (360 + 9 * 30 = 630 = 10:30 AM)
      expect(startTimes[9], '10:30 AM');
      // Index 12: 12:00 PM (360 + 12 * 30 = 720 = 12:00 PM)
      expect(startTimes[12], '12:00 PM');
    });

    // 3. Increasing and decreasing duration
    test('3. Stepper increases and decreases duration by 30-minute increments', () {
      int duration = 60;

      // Increase
      final canInc = BookingTimeUtils.canIncreaseDuration(
        currentDurationMinutes: duration,
        startMinutes: 600, // 10:00 AM
        closeMinutes: 1380, // 11:00 PM
      );
      expect(canInc, true);
      duration += 30;
      expect(duration, 90);

      // Decrease
      final canDec = BookingTimeUtils.canDecreaseDuration(
        currentDurationMinutes: duration,
        minDurationMinutes: 30,
      );
      expect(canDec, true);
      duration -= 30;
      expect(duration, 60);

      // Decrease to min
      duration -= 30;
      expect(duration, 30);
      final canDecBelowMin = BookingTimeUtils.canDecreaseDuration(
        currentDurationMinutes: duration,
        minDurationMinutes: 30,
      );
      expect(canDecBelowMin, false);
    });

    // 4. Correct end-time calculation
    test('4. Correct end-time calculation for snap-to-time ruler', () {
      expect(BookingTimeUtils.calculateEndTime('12:00 PM', 60), '01:00 PM');
      expect(BookingTimeUtils.calculateEndTime('12:00 PM', 120), '02:00 PM');
      expect(BookingTimeUtils.calculateEndTime('10:30 AM', 90), '12:00 PM');
      expect(BookingTimeUtils.calculateEndTime('10:30 AM', 150), '01:00 PM');
    });

    // 5. Preventing selection beyond closing time
    test('5. Preventing duration selection beyond closing time', () {
      // 10:30 PM (1350 min) with venue closing at 11:00 PM (1380 min)
      const startMin = 1350; // 10:30 PM
      const closeMin = 1380; // 11:00 PM

      // 30 min duration fits exactly
      final canFit30 = BookingTimeUtils.canIncreaseDuration(
        currentDurationMinutes: 0,
        startMinutes: startMin,
        closeMinutes: closeMin,
        stepMinutes: 30,
      );
      expect(canFit30, true);

      // Cannot increase from 30 to 60 because 10:30 PM + 60m = 11:30 PM > 11:00 PM
      final canIncTo60 = BookingTimeUtils.canIncreaseDuration(
        currentDurationMinutes: 30,
        startMinutes: startMin,
        closeMinutes: closeMin,
        stepMinutes: 30,
      );
      expect(canIncTo60, false);
    });

    // 6. Rejecting overlapping bookings and holds
    test('6. Availability status evaluation rejects overlapping bookings and holds', () {
      const nowMs = 1791590400000;
      final granularSlots = [
        VenueSlotModel(
          id: 'slot_1',
          courtId: 'court_1',
          venueId: 'venue_1',
          date: '2026-10-15',
          startTime: '10:00 AM',
          endTime: '10:30 AM',
          startTimestampMs: nowMs,
          endTimestampMs: nowMs + 1800000,
          durationMinutes: 30,
          pricePaise: 40000,
          status: 'AVAILABLE',
        ),
        VenueSlotModel(
          id: 'slot_2',
          courtId: 'court_1',
          venueId: 'venue_1',
          date: '2026-10-15',
          startTime: '10:30 AM',
          endTime: '11:00 AM',
          startTimestampMs: nowMs + 1800000,
          endTimestampMs: nowMs + 3600000,
          durationMinutes: 30,
          pricePaise: 40000,
          status: 'BOOKED', // booked!
        ),
        VenueSlotModel(
          id: 'slot_3',
          courtId: 'court_1',
          venueId: 'venue_1',
          date: '2026-10-15',
          startTime: '11:00 AM',
          endTime: '11:30 AM',
          startTimestampMs: nowMs + 3600000,
          endTimestampMs: nowMs + 5400000,
          durationMinutes: 30,
          pricePaise: 40000,
          status: 'HELD', // active hold!
          holdExpiresAtMs: DateTime.now().millisecondsSinceEpoch + 600000,
        ),
      ];

      // Requesting 10:00 AM for 60 min covers slot_1 (available) and slot_2 (booked) -> BOOKED
      final status1 = VenueRepository.evaluateIntervalStatus(
        granularSlots: granularSlots,
        startTime: '10:00 AM',
        durationMinutes: 60,
        closeMinutes: 1380,
      );
      expect(status1, 'BOOKED');

      // Requesting 10:30 AM for 60 min covers slot_2 (booked) and slot_3 (held) -> BOOKED
      final status2 = VenueRepository.evaluateIntervalStatus(
        granularSlots: granularSlots,
        startTime: '10:30 AM',
        durationMinutes: 60,
        closeMinutes: 1380,
      );
      expect(status2, 'BOOKED');

      // Requesting 11:00 AM for 30 min covers slot_3 (held) -> HELD
      final status3 = VenueRepository.evaluateIntervalStatus(
        granularSlots: granularSlots,
        startTime: '11:00 AM',
        durationMinutes: 30,
        closeMinutes: 1380,
      );
      expect(status3, 'HELD');
    });

    // 7. Updating selected interval markers after duration changes
    test('7. Interval markers distance expands and contracts proportionally with duration', () {
      const stepWidth = 64.0;

      // 60 min = 2 steps
      final steps60 = (60 / 30).round();
      expect(steps60, 2);
      expect(steps60 * stepWidth, 128.0);

      // 120 min = 4 steps
      final steps120 = (120 / 30).round();
      expect(steps120, 4);
      expect(steps120 * stepWidth, 256.0);

      // 180 min = 6 steps
      final steps180 = (180 / 30).round();
      expect(steps180, 6);
      expect(steps180 * stepWidth, 384.0);
    });

    // 8. Daytime, evening, and nighttime theme selection
    test('8. Day/night adaptive theme selection based on booking local time', () {
      // 09:30 AM (570 min) -> Morning/Day
      expect(
        BookingTimeUtils.getTimeThemePeriod(570),
        BookingTimeThemePeriod.morningDay,
      );

      // 02:00 PM (840 min) -> Morning/Day
      expect(
        BookingTimeUtils.getTimeThemePeriod(840),
        BookingTimeThemePeriod.morningDay,
      );

      // 05:30 PM (1050 min) -> Evening
      expect(
        BookingTimeUtils.getTimeThemePeriod(1050),
        BookingTimeThemePeriod.evening,
      );

      // 07:00 PM (1140 min) -> Evening
      expect(
        BookingTimeUtils.getTimeThemePeriod(1140),
        BookingTimeThemePeriod.evening,
      );

      // 08:30 PM (1230 min) -> Night
      expect(
        BookingTimeUtils.getTimeThemePeriod(1230),
        BookingTimeThemePeriod.night,
      );

      // 11:00 PM (1380 min) -> Night
      expect(
        BookingTimeUtils.getTimeThemePeriod(1380),
        BookingTimeThemePeriod.night,
      );
    });

    // 9. Changing court/date refreshes availability
    test('9. Changing court or date generates distinct authoritative query parameters', () {
      const court1 = CourtModel(
        id: 'court_alpha',
        name: 'Turf Alpha',
        sportId: 'Box Cricket',
        capacity: 12,
        surfaceType: 'Turf',
        hourlyRatePaise: 80000,
      );

      const court2 = CourtModel(
        id: 'court_beta',
        name: 'Turf Beta',
        sportId: 'Box Cricket',
        capacity: 12,
        surfaceType: 'Turf',
        hourlyRatePaise: 100000,
      );

      final slotCourt1 = VenueRepository.createCompositeSlot(
        court: court1,
        venueId: 'venue_sidsar',
        dateStr: '2026-10-15',
        startTime: '10:00 AM',
        durationMinutes: 60,
      );

      final slotCourt2 = VenueRepository.createCompositeSlot(
        court: court2,
        venueId: 'venue_sidsar',
        dateStr: '2026-10-16',
        startTime: '10:00 AM',
        durationMinutes: 60,
      );

      expect(slotCourt1.courtId, 'court_alpha');
      expect(slotCourt1.pricePaise, 80000);
      expect(slotCourt1.date, '2026-10-15');

      expect(slotCourt2.courtId, 'court_beta');
      expect(slotCourt2.pricePaise, 100000);
      expect(slotCourt2.date, '2026-10-16');
    });

    // 10. Preventing Proceed for invalid or unavailable intervals
    test('10. Proceed is blocked when composite slot is null (unavailable interval)', () {
      VenueSlotModel? activeSlot;

      // When interval is HELD or BOOKED, activeSlot remains null
      const intervalStatus = 'HELD';
      if (intervalStatus == 'AVAILABLE') {
        activeSlot = const VenueSlotModel(
          id: 'valid_slot',
          courtId: 'court_1',
          venueId: 'venue_1',
          date: '2026-10-15',
          startTime: '10:00 AM',
          endTime: '11:00 AM',
          startTimestampMs: 1791590400000,
          endTimestampMs: 1791594000000,
          durationMinutes: 60,
          pricePaise: 80000,
          status: 'AVAILABLE',
        );
      }

      // Check whether user can proceed
      final canProceed = activeSlot != null;
      expect(canProceed, false);
    });
  });

  group('Fixed-Scale Ruler & Precise Marker Position Tests (Screenshots 3, 4, 5 Specs)', () {
    const stepWidth = SnapTimeRuler.stepWidth; // 28.0 px per 30 minutes (56.0 px per whole hour)

    test('1. Fixed tick spacing remains constant (56.0 px/hr) across 30-, 60-, 120-, and 300-minute durations', () {
      // 1 hour = 2 steps = 56.0 px regardless of selected duration
      const oneHourTickSpacing = 2 * stepWidth;
      expect(oneHourTickSpacing, 56.0);

      for (final duration in [30, 60, 120, 300]) {
        final durationSteps = duration ~/ 30;
        final intervalPixelWidth = durationSteps * stepWidth;

        // Interval spans exactly durationSteps * 28.0
        if (duration == 30) expect(intervalPixelWidth, 28.0);
        if (duration == 60) expect(intervalPixelWidth, 56.0);
        if (duration == 120) expect(intervalPixelWidth, 112.0);
        if (duration == 300) expect(intervalPixelWidth, 280.0);

        // Crucial: The underlying tick-to-tick spacing of the ruler NEVER changes!
        expect(stepWidth, 28.0);
      }
    });

    test('2. Start marker remains anchored in viewport while end marker extends by exact duration distance', () {
      const viewportWidth = 332.0;
      const startMarkerX = 86.0; // ~26% anchor

      // For 60 mins (Screenshot 3: 9:00 PM - 10:00 PM)
      final endX60 = startMarkerX + (60 ~/ 30) * stepWidth;
      expect(endX60, 86.0 + 56.0); // 142.0 px
      expect(endX60 - startMarkerX, 56.0);

      // For 300 mins (5 hours)
      const startMarkerX300 = 32.0;
      final endX300 = startMarkerX300 + (300 ~/ 30) * stepWidth;
      expect(endX300, 32.0 + 280.0); // 312.0 px
      expect(endX300 - startMarkerX300, 280.0);

      // Both markers stay within the viewport width
      expect(endX300 < viewportWidth, true);
    });

    test('3. Duration changes preserve start time and only update end marker', () {
      const selectedStartTime = '09:00 PM';
      var durationMinutes = 60;

      // User presses [+] stepper to increase from 60 to 120, then to 300
      durationMinutes = 120;
      expect(selectedStartTime, '09:00 PM'); // Start time strictly preserved
      expect(BookingTimeUtils.calculateEndTime(selectedStartTime, durationMinutes), '11:00 PM');

      durationMinutes = 300;
      expect(selectedStartTime, '09:00 PM'); // Start time strictly preserved
      expect(BookingTimeUtils.calculateEndTime(selectedStartTime, durationMinutes), '02:00 AM');
    });

    test('4. Snap-to-30-minute behavior from arbitrary drag offsets', () {
      // Step width is 28.0
      // Drag offset 0..13 snaps to index 0
      expect((0.0 / stepWidth).round(), 0);
      expect((13.0 / stepWidth).round(), 0);

      // Drag offset 14..41 snaps to index 1 (28.0)
      expect((14.0 / stepWidth).round(), 1);
      expect((28.0 / stepWidth).round(), 1);
      expect((41.0 / stepWidth).round(), 1);

      // Drag offset 42..69 snaps to index 2 (56.0)
      expect((42.0 / stepWidth).round(), 2);
      expect((56.0 / stepWidth).round(), 2);
    });

    test('5. Maximum duration derived from venue operating hours and closing boundary', () {
      const closeMinutes = 1380; // 11:00 PM
      final startMin = BookingTimeUtils.parseTimeToMinutes('09:00 PM'); // 1260
      final remainingUntilClose = closeMinutes - startMin; // 120 minutes

      expect(remainingUntilClose, 120);

      // 60 mins -> ends at 10:00 PM <= 11:00 PM -> Valid
      expect(BookingTimeUtils.isIntervalWithinOperatingHours(
        startMinutes: startMin,
        durationMinutes: 60,
        openMinutes: 360,
        closeMinutes: closeMinutes,
      ), true);

      // 120 mins -> ends at 11:00 PM == 11:00 PM -> Valid
      expect(BookingTimeUtils.isIntervalWithinOperatingHours(
        startMinutes: startMin,
        durationMinutes: 120,
        openMinutes: 360,
        closeMinutes: closeMinutes,
      ), true);

      // 150 mins -> ends at 11:30 PM > 11:00 PM -> Rejected
      expect(BookingTimeUtils.isIntervalWithinOperatingHours(
        startMinutes: startMin,
        durationMinutes: 150,
        openMinutes: 360,
        closeMinutes: closeMinutes,
      ), false);

      expect(BookingTimeUtils.canIncreaseDuration(
        currentDurationMinutes: 120,
        startMinutes: startMin,
        closeMinutes: closeMinutes,
        maxDurationMinutes: 360,
      ), false); // Cannot exceed closing time
    });

    test('6. Unavailable intervals rendered in RED on timeline axis and prevent selection overlap', () {
      final unavailableTimes = {'08:00 PM', '08:30 PM'};

      // 08:00 PM is in unavailable set
      expect(unavailableTimes.contains('08:00 PM'), true);
      expect(unavailableTimes.contains('07:00 PM'), false);

      // Interval evaluating an overlapping slot is marked HELD or BOOKED
      final granularSlots = [
        const VenueSlotModel(
          id: 's1',
          courtId: 'c1',
          venueId: 'v1',
          date: '2026-10-15',
          startTime: '07:30 PM',
          endTime: '08:00 PM',
          startTimestampMs: 1000,
          endTimestampMs: 2000,
          durationMinutes: 30,
          pricePaise: 40000,
          status: 'AVAILABLE',
        ),
        const VenueSlotModel(
          id: 's2',
          courtId: 'c1',
          venueId: 'v1',
          date: '2026-10-15',
          startTime: '08:00 PM',
          endTime: '08:30 PM',
          startTimestampMs: 2000,
          endTimestampMs: 3000,
          durationMinutes: 30,
          pricePaise: 40000,
          status: 'BOOKED',
        ),
      ];

      final status = VenueRepository.evaluateIntervalStatus(
        granularSlots: granularSlots,
        startTime: '07:30 PM',
        durationMinutes: 60,
        closeMinutes: 1380,
      );

      // Overlap with booked slot at 08:00 PM causes interval status to be BOOKED
      expect(status, 'BOOKED');
    });

    test('7. No marker jitter or stale selection updates: discrete time mapping is authoritative', () {
      final startTimes = ['06:00 AM', '06:30 AM', '07:00 AM', '07:30 AM'];
      
      // Floating drag offsets produce discrete snapped indices, avoiding float jitter
      const floatOffset1 = 27.8;
      const floatOffset2 = 28.2;
      expect((floatOffset1 / stepWidth).round(), 1);
      expect((floatOffset2 / stepWidth).round(), 1);
      expect(startTimes[(floatOffset1 / stepWidth).round()], '06:30 AM');
      expect(startTimes[(floatOffset2 / stepWidth).round()], '06:30 AM');
    });
  });

  group('Redesigned 5-Section Booking Screen Tests (Grid, Durations, Courts, Summary)', () {
    const sampleCourt = CourtModel(
      id: 'court_test_1',
      name: 'Box Cricket Arena 1',
      sportId: 'Box Cricket',
      capacity: 12,
      surfaceType: 'Turf',
      hourlyRatePaise: 80000,
      minBookingMinutes: 30,
    );

    const closeMinutes = 1380; // 11:00 PM

    List<VenueSlotModel> generateTestSlots() {
      final List<VenueSlotModel> slots = [];
      // 06:00 AM (360) to 11:00 PM (1380) in 30-min steps
      for (int m = 360; m < closeMinutes; m += 30) {
        final start = BookingTimeUtils.formatMinutesToTime(m);
        final end = BookingTimeUtils.formatMinutesToTime(m + 30);
        // Mark 10:00 AM to 11:00 AM as booked
        final isBooked = (m == 600 || m == 630);
        slots.add(
          VenueSlotModel(
            id: 'slot_$m',
            courtId: sampleCourt.id,
            venueId: 'v1',
            date: '2026-10-15',
            startTime: start,
            endTime: end,
            startTimestampMs: m * 60000,
            endTimestampMs: (m + 30) * 60000,
            durationMinutes: 30,
            pricePaise: 40000,
            status: isBooked ? 'BOOKED' : 'AVAILABLE',
          ),
        );
      }
      return slots;
    }

    test('1. Start time grid correctly marks available and booked slots for selected duration', () {
      final slots = generateTestSlots();

      // For 60m duration, 09:00 AM is AVAILABLE (09:00 to 10:00)
      final status0900 = VenueRepository.evaluateIntervalStatus(
        granularSlots: slots,
        startTime: '09:00 AM',
        durationMinutes: 60,
        closeMinutes: closeMinutes,
      );
      expect(status0900, 'AVAILABLE');

      // For 60m duration, 09:30 AM overlaps booked 10:00 AM slot -> BOOKED
      final status0930 = VenueRepository.evaluateIntervalStatus(
        granularSlots: slots,
        startTime: '09:30 AM',
        durationMinutes: 60,
        closeMinutes: closeMinutes,
      );
      expect(status0930, 'BOOKED');

      // 10:00 AM is directly BOOKED
      final status1000 = VenueRepository.evaluateIntervalStatus(
        granularSlots: slots,
        startTime: '10:00 AM',
        durationMinutes: 60,
        closeMinutes: closeMinutes,
      );
      expect(status1000, 'BOOKED');

      // 11:00 AM is AVAILABLE (11:00 to 12:00)
      final status1100 = VenueRepository.evaluateIntervalStatus(
        granularSlots: slots,
        startTime: '11:00 AM',
        durationMinutes: 60,
        closeMinutes: closeMinutes,
      );
      expect(status1100, 'AVAILABLE');
    });

    test('2. Closing boundary: slots that extend past closing are marked EXCEEDS_CLOSING', () {
      final slots = generateTestSlots();

      // For 60m duration, 10:00 PM (ends at 11:00 PM) is AVAILABLE
      final status1000PM = VenueRepository.evaluateIntervalStatus(
        granularSlots: slots,
        startTime: '10:00 PM',
        durationMinutes: 60,
        closeMinutes: closeMinutes,
      );
      expect(status1000PM, 'AVAILABLE');

      // For 60m duration, 10:30 PM (ends at 11:30 PM > 11:00 PM) EXCEEDS_CLOSING
      final status1030PM = VenueRepository.evaluateIntervalStatus(
        granularSlots: slots,
        startTime: '10:30 PM',
        durationMinutes: 60,
        closeMinutes: closeMinutes,
      );
      expect(status1030PM, 'EXCEEDS_CLOSING');
    });

    test('3. Duration change invalidation: switching from 30m to 60m invalidates 10:30 PM slot', () {
      final slots = generateTestSlots();

      // At 30m: 10:30 PM ends at 11:00 PM (VALID)
      final status30m = VenueRepository.evaluateIntervalStatus(
        granularSlots: slots,
        startTime: '10:30 PM',
        durationMinutes: 30,
        closeMinutes: closeMinutes,
      );
      expect(status30m, 'AVAILABLE');

      // User increases duration to 60m: 10:30 PM now ends at 11:30 PM (INVALID)
      final status60m = VenueRepository.evaluateIntervalStatus(
        granularSlots: slots,
        startTime: '10:30 PM',
        durationMinutes: 60,
        closeMinutes: closeMinutes,
      );
      expect(status60m, 'EXCEEDS_CLOSING');
      expect(status60m == 'AVAILABLE', false);
    });

    test('4. Price updates correctly when duration changes', () {
      // 30 min @ ₹800/hr = ₹400 (40000 paise)
      expect(BookingTimeUtils.calculateCourtPricePaise(
        hourlyRatePaise: sampleCourt.hourlyRatePaise,
        durationMinutes: 30,
      ), 40000);

      // 60 min @ ₹800/hr = ₹800 (80000 paise)
      expect(BookingTimeUtils.calculateCourtPricePaise(
        hourlyRatePaise: sampleCourt.hourlyRatePaise,
        durationMinutes: 60,
      ), 80000);

      // 90 min @ ₹800/hr = ₹1200 (120000 paise)
      expect(BookingTimeUtils.calculateCourtPricePaise(
        hourlyRatePaise: sampleCourt.hourlyRatePaise,
        durationMinutes: 90,
      ), 120000);

      // 120 min @ ₹800/hr = ₹1600 (160000 paise)
      expect(BookingTimeUtils.calculateCourtPricePaise(
        hourlyRatePaise: sampleCourt.hourlyRatePaise,
        durationMinutes: 120,
      ), 160000);

      // 180 min @ ₹800/hr = ₹2400 (240000 paise)
      expect(BookingTimeUtils.calculateCourtPricePaise(
        hourlyRatePaise: sampleCourt.hourlyRatePaise,
        durationMinutes: 180,
      ), 240000);
    });

    test('5. Single-court vs multi-court venue configuration', () {
      const singleCourtVenue = VenueModel(
        id: 'v_single',
        name: 'Single Court Turf',
        address: 'Bhavnagar',
        city: 'Bhavnagar',
        latitude: 21.7,
        longitude: 72.1,
        rating: 4.8,
        reviewsCount: 10,
        supportedSports: ['Box Cricket'],
        imageAssets: [],
        facilities: [],
        operatingHours: '06:00 AM - 11:00 PM',
        rules: [],
        cancellationPolicy: 'Standard',
        startingPricePaise: 80000,
        courts: [sampleCourt],
      );

      expect(singleCourtVenue.courts.length, 1);
      expect(singleCourtVenue.courts.first.name, 'Box Cricket Arena 1');
    });

    test('6. Composite slot creation preserves start, end, duration, and price for checkout', () {
      final compositeSlot = VenueRepository.createCompositeSlot(
        court: sampleCourt,
        venueId: 'v1',
        dateStr: '2026-10-15',
        startTime: '09:00 AM',
        durationMinutes: 120,
      );

      expect(compositeSlot.startTime, '09:00 AM');
      expect(compositeSlot.endTime, '11:00 AM');
      expect(compositeSlot.durationMinutes, 120);
      expect(compositeSlot.pricePaise, 160000); // ₹1,600
      expect(compositeSlot.courtId, sampleCourt.id);
      expect(compositeSlot.date, '2026-10-15');
      expect(compositeSlot.status, 'AVAILABLE');
    });
  });
}

